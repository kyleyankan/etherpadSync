#!/usr/bin/perl
# Kyle Yankanich KyleYankanich@gmail.com 2013
# For use with etherpad API v 1.2.1
# 

use LWP::Simple;
use JSON qw( decode_json );
use URI::Escape;
use File::stat;


#Let's bring in your API key, and default settings such as pad to modify, etherpad host, and the localfilename
require "etherpadConfig.pl";

$etherpadJSON = get("http://" . $etherpadDomain . "/api/1.2.1/listAllPads?apikey=" . $etherpadAPI);
die "Cannot connect to $etherpadDomain" unless $etherpadJSON;
$etherpadlist = decode_json( $etherpadJSON );        


if (! -d "./$etherpadDomain") { mkdir "./$etherpadDomain"; }

foreach $padID (@{$etherpadlist->{'data'}{'padIDs'}}) {


	my $etherpadJSON = get("http://" . $etherpadDomain . "/api/1.2.1/getRevisionsCount?apikey=" . $etherpadAPI . "&padID=" . $padID);
	die "Cannot connect to $etherpadDomain" unless $etherpadJSON;
	my $etherpadRev = decode_json( $etherpadJSON );


        my $etherpadJSON = get("http://" . $etherpadDomain . "/api/1.2.1/getText?apikey=" . $etherpadAPI . "&padID=" . $padID);
        die "Cannot connect to $etherpadDomain" unless $etherpadJSON;
        my $etherpadContent = decode_json( $etherpadJSON );

	$padHash{$padID} = [$etherpadRev->{'data'}{'revisions'}, length ($etherpadContent->{'data'}{'text'})];
	print "$padID - ./$etherpadDomain/$padID.txt \n";
	&CompareFileEther($etherpadAPI, $padID, $etherpadDomain, "./$etherpadDomain/$padID.txt"); #Compares file/pad in etherpadConfig.


	#sleep 5;
}


sub CompareFileEther() {
        local($etherpadAPI, $etherpadPad, $etherpadDomain, $filename) = ($_[0],$_[1],$_[2],$_[3]); 

        #Get the etherpad data in JSON form, parse it out, and store it.
        $etherpadJSON = get("http://" . $etherpadDomain . "/api/1/getText?apikey=" . $etherpadAPI . "&padID=" . $etherpadPad );
        die "Cannot connect to $etherpadDomain" unless $etherpadJSON;
        $etherpadContents = decode_json( $etherpadJSON );        
        
        #print "CONTENTS OF ETHERPAD TEXT:\n";
        #print $etherpadContents->{'data'}{'text'};


        #Get the local file data and store it.
        {
                local $/=undef;
                open(TODO, "<./" . $filename);
                $fileContents = <TODO>;
                close(TODO);
        }
        #print "\n\nCONTENTS TO $filename :\n";
        #print $fileContents;

        #Get the etherpad's last modified time in UTC and store it
        $etherpadJSON = get("http://" . $etherpadDomain . "/api/1/getLastEdited?apikey=" . $etherpadAPI . "&padID=" . $etherpadPad );
        die "Cannot connect to $etherpadDomain" unless $etherpadJSON;
        $etherpadEdited = decode_json( $etherpadJSON );
	
	if (-f $filename) {		
       		#Get the local file's last modified time and store it 
               $fileEdited = stat($filename)->mtime;
	} else {
		$fileEdited = 0;
	}
        #print "\n\nFILE LAST EDITED: $fileEdited\n";

        #If the data in the etherpad and file are the same, no action is needed
        if ($fileContents eq $etherpadContents->{'data'}{'text'}) {
                print "\tFILES ARE THE SAME, NO UPDATE\n";
        } else {
                if ($fileEdited > ($etherpadEdited->{'data'}{'lastEdited'} / 1000 ) ) {
                        #If the file is more recent, push it to the Etherpad
                        print "\tFILE COPY MORE RECENT\n";

                        $encodedFile = uri_escape( $fileContents );
                        $etherpadJSON = get("http://" . $etherpadDomain . "/api/1/setText?apikey=" . $etherpadAPI .
                         "&padID=" . $etherpadPad  . "&text=$encodedFile");
                } else {
                        #If the Etherpad is more recent, save it to the local file
			if ($filename eq $0) { return; }
			if ($fileEdited = 0) { print `touch $filename`; }
                        print "\tETHERPAD COPY MORE RECENT\n";
                        open(TODO, ">$filename");
                        print TODO $etherpadContents->{'data'}{'text'};
                        close(TODO);        

                }
        }
}

