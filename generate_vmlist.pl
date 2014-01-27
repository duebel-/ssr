#!/usr/bin/perl

use strict;
use warnings;
use VMware::VIFPLib;

my $filename = $ARGV[0];

open(VMLIST,">$filename");

my $vima_target = VmaTargetLib::query_target("vcenter.server");
#print $vima_target->name() . "\n";
$vima_target->login();
my $entity_views = Vim::find_entity_views(view_type => "VirtualMachine");
foreach my $entity_view (@$entity_views) {
        my $entity_name = $entity_view->name;
        #print $entity_name;
        if ( ($entity_view->runtime->powerState->val eq 'poweredOn') )
        {
                #print " is on. => Adding to savelist.\n";
                print VMLIST "$entity_name\n";
        } else {
                #print " is off.\n";
        }
}

close VMLIST;
