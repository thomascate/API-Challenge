#!/usr/bin/perl
use LWP;
use LWP::Protocol::https;
use JSON qw( decode_json to_json );
use Getopt::Std;
use Data::Dumper;
$Data::Dumper::Indent = 1;

$fail    = 0;
$wait    = 0;
%ips     = ();
%roots   = ();
%servers = ();

get_input();
get_credentials();
do_auth();
do_build();
get_ips();

exit 0;

sub get_input
{

  getopts('n:c:h:i:f:r:',\%opt);

  if ($opt{'h'}){
    do_usage();
  }

  if ($opt{'n'}){
    $name = "$opt{'n'}";
  }

  if ($opt{'c'}){
    $count = int("$opt{'c'}");
  }
  else{
    $count = 1;
  }

  if ($opt{'i'}){
    $image = "$opt{'i'}";
  }

  if ($opt{'f'}){
    #$flavor = int("$opt{'f'}");
    $flavor = "$opt{'f'}";
  }

  $region = 'ORD';
  if ($opt{'r'}){
    if ($opt{'r'} =~ /ORD/i){
     $region = 'ORD';
    }
    elsif ($opt{'r'} =~ /DFW/i){
      $region = 'DFW';
    }
    else{
      die "I didn't understand your region, please use ORD or DFW\n";
    }

  }


  else{
   do_usage();
   exit 1;
  } 

}


sub get_credentials
{
  open CREDS, "<", $ENV{"HOME"} . "/.rackspace_cloud_credentials" or die $!;

  while (<CREDS>){

    if($_ =~ m/username.*/){
      $username = (split(/\s+/,$_))[-1];
#      print $username;
    }

    if($_ =~ m/api\_key.*/){
      $api_key = (split(/\s+/,$_))[-1];
#      print $api_key;
    }

  }
}

#Auth pulls the users auth_token, as well as their service catalog, serviceCatalog is a hash reference that contains all services, locations and public urls
#
sub do_auth
{
  my $auth_url = 'https://auth.api.rackspacecloud.com/v1.1/auth';
  my $auth_json =  '{"credentials":{"username":"' . $username . '","key":"' . $api_key . '"}}';
  my $auth_request = HTTP::Request->new( 'POST', $auth_url ) ;
  $auth_request->header( 'Content-Type' => 'application/json' );
  $auth_request->content( $auth_json );

  my $auth_lwp = LWP::UserAgent->new;
  my $auth_content = $auth_lwp->request( $auth_request );
  my $response_code = $auth_content->status_line, "\n";

  if ($response_code eq '200 OK'){

    $auth_content = $auth_content->decoded_content;
#    print Dumper($auth_content);
    $auth_content = decode_json( $auth_content );

    $auth_token = $auth_content->{'auth'}{'token'}{'id'};
    $auth_expires = $auth_content->{'auth'}{'token'}{'expires'};

    $service_catalog = $auth_content->{'auth'}{'serviceCatalog'};

    #about %90 of the time [0] is dfw, have to do this to fix for the inconsistent api
 
    @temp = $service_catalog->{'cloudServersOpenStack'}; 
    $size = @temp;
    $i    = 0;
    while ($i<=$size){
      if ($service_catalog->{'cloudServersOpenStack'}[$i]{'region'} eq $region){
        $public_url = $service_catalog->{'cloudServersOpenStack'}[$i]{'publicURL'} . '/servers';
      }
    $i++;
    }

  }


  else{
    print "$response_code\n\n";
    print print Dumper($auth_content);
    exit 1;
  }

  return ($auth_token, $auth_expires, $service_catalog, $public_url);

}

sub do_build
{

  for ( $i = 1; $i <= $count; $i++ ){

    %build_request = (
      name           => $name . $i,
      flavorRef      => $flavor,
      imageRef       => $image
     );
    my $build_json = to_json(\%build_request);

#   this is hacky 
    $build_json = "{\"server\":" . $build_json . "}";
#    print "$build_json\n";

    my $build_req = HTTP::Request->new( 'POST', $public_url );
    $build_req->header( 
      'Content-Type' => 'application/json',
      'X-Auth-Token' => $auth_token
     );

    $build_req->content( $build_json );

    my $lwp = LWP::UserAgent->new;
    my $response = $lwp->request( $build_req );

    if ($response->is_success) {
      print "Sent build request for server $name$i\n";
      my $decoded_json = decode_json( $response->content );
      $uuid = $decoded_json->{'server'}{'id'};
      $root_pass = $decoded_json->{'server'}{'adminPass'};
      $servers{ $uuid } = 0;
      $roots{ $uuid } = $root_pass;
      $uuid = ();
      $root_pass = ();
    }

    else {
      print "$public_url\n";
      print "$auth_token\n";
      print "$build_json\n";
      print $response->status_line, "\n";
      $fail++;
      $i--;
      if ($fail>2){ die "Too many failures"; }  
    }

  }

  print "Finished sending build requests. Waiting for IPs to be assigned, this can take quite some time.\n";
  sleep (90);

}
    
sub get_ips
{
  for (keys %servers){

    $server_url = $public_url . "/" . $_;
#    print "$server_url\n";

    if ($servers->{$_} == 0){
 
      my $ip_req = HTTP::Request->new( 'GET', $server_url );
      $ip_req->header(
        'X-Auth-Token' => $auth_token
       );

      my $lwp = LWP::UserAgent->new;
      my $response = $lwp->request( $ip_req );

    if ($response->is_success) {
      my $decoded_json = decode_json( $response->content );

      if ($decoded_json->{'server'}{'accessIPv4'}){
        $servers->{$_} = $decoded_json->{'server'}{'accessIPv4'};
        $ip =  $decoded_json->{'server'}{'accessIPv4'};
        $ips->{$_} = $ip;
        $name = $decoded_json->{'server'}{'name'};
        $pass = $roots{$_};
        print "$name: IP: $ip Password: $pass \n";   
        $ip = ();
      }
      else{
        if ($wait>5){die "five minutes without IP address returned\n"};
#        print "no IP found yet, waiting\n";
        sleep(60);
        $wait++;
        get_ips();
      }
    }

      else {
        print $response->status_line, "\n";
        $fail++;
        if ($fail>4){ die "Too many failures"; }
        sleep(5);
        get_ips();
      }


    }

  }
}


sub do_usage
{

  print "Build an arbitrary number of servers.\n\n";
  print "-h display this message\n";
  print "-n server basename\n";
  print "-c server count\n";
  print "-i image id\n";
  print "-f flavr id\n";
  print "-r region, ORD or DFW\n";

}
