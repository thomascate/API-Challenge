API-Challenge
=============

Rackspace API Challenges  

I'm doing these in Perl because that is the method in which I rotate forward.  
You will need perl JSON and LWP for basically all of these.  

1. This takes the following flags,  
-f flavor (2 for challenge)  
-n name (base name, will have number appended)  
-i image id (I like 03318d19-b6e6-4092-9b5c-4758ee0ada60 but this works with any image)  
-c count (3 for challenge)  

Example output,  
[tcate@challenge 1]$ ./challenge1.pl -f 2 -n challenge -i 03318d19-b6e6-4092-9b5c-4758ee0ada60 -c 3  
Sent build request for server challenge1  
Sent build request for server challenge2  
Sent build request for server challenge3  
Finished sending build requests. Waiting for IPs to be assigned, this can take quite some time.  
challenge1: IP: 166.78.249.159 Password: QipL2NsMKfPQ   
challenge3: IP: 166.78.249.8 Password: CqqrADH2LqZk   
challenge2: IP: 166.78.249.214 Password: jt772GAbeNoN   
