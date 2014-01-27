#!/usr/bin/perl

use strict;
use warnings;
use POSIX;
use VMware::VIFPLib;
use VMware::VIExt;
use Getopt::Long;

$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0; #LWP shall not verify certs (default as of ver 6)

my $Name = $0;
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
my $o_host = undef;
my $o_storagename = undef;
my $o_warn = undef;          # warning limit
my $o_crit = undef;          # critical limit
my $o_help = undef;          # wan't some help ?
my $testmode = undef;
my $state = "";
my $output = "";

sub check_options {
    Getopt::Long::Configure ("bundling");
    GetOptions(
        'h'     => \$o_help,            'help'          => \$o_help,
        'H:s'   => \$o_host,            'hostname:s'    => \$o_host,
        'c:s'   => \$o_crit,            'critical:s'    => \$o_crit,
        'w:s'   => \$o_warn,            'warn:s'        => \$o_warn,
        'd:s'   => \$o_storagename,     'datastore:s'   => \$o_storagename
    );
    if (defined($o_help) ) { help(); exit $ERRORS{"UNKNOWN"}};
    if ( ! defined($o_host) || !defined($o_warn) || !defined($o_crit)) { print_usage(); exit $ERRORS{"UNKNOWN"}};
    # Get rid of % sign
    if (($o_warn =~ m/\%$/)&&($o_crit =~ m/\%$/)) { $testmode = "relative"; } else { $testmode = "absolute"; }
    $o_warn =~ s/\%//;
    $o_crit =~ s/\%//;
    if ((isnnum($o_warn)) || (isnnum($o_crit))) { print " warn and crit must be numbers\n";print_usage(); exit $ERRORS{"UNKNOWN"}};
    # Check for positive numbers
    if (($o_warn < 0) || ($o_crit < 0)) { print " warn and critical > 0 \n";print_usage(); exit $ERRORS{"UNKNOWN"}};
    # Check warning and critical values
    if ($o_warn <= $o_crit) { print " warn > crit\n";print_usage(); exit $ERRORS{"UNKNOWN"}};
}

sub help {
   print "\nVMWare datastore monitor for Nagios\n";
   print "(c)yes\n\n";
   print_usage();
   print <<EOT;
By default, plugin will monitor %free on datastores :
warn if %free < warn and critical if %free < crit
-h, --help
   print this help message
-H, --hostname=HOST
   name or IP address of host to check
-d, --datastore=DATASTORENAME
   name of datastore in ESX(i)/vSphere without brackets e.g. [datastore0] -> datastore
-w, --warn=<n[%]>
   warning level in %
-c, --critical=<n[%]>
   critical level in %

EOT
}

sub print_usage {
    print "Usage: $Name -H <host> [-d <datastorename>] -w <warn_level> -c <crit_level>\n";
}

sub isnnum { # Return true if arg is not a number
  my $num = shift;
  if ( $num =~ /^-?(\d+\.?\d*)|(^\.\d+)$/ ) { return 0 ;}
  return 1;
}


sub round ($$) {
    sprintf "%.$_[1]f", $_[0];
}

###MAIN


check_options();

my $vima_target = VmaTargetLib::query_target($o_host);
$vima_target->login();

my $host_view = VIExt::get_host_view(1, ['datastore', 'config.fileSystemVolume.mountInfo']);
Opts::assert_usage(defined($host_view), "Invalid host.");
my $mounts = $host_view->{'config.fileSystemVolume.mountInfo'};
my $datastoreRefs = $host_view->datastore;
my %capacity;
my %name;
my %free;
my %usagefraction;
foreach (@$mounts) {
 my $path = $_->mountInfo->path;
 $capacity{$path} = $_->volume->capacity;
 $name{$path} = $_->volume->name;
}
foreach (@$datastoreRefs) {
 my $datastore = Vim::get_view(mo_ref => $_);
 my $path = $datastore->info->url;
 $free{$path} = $datastore->info->freeSpace;
}

my @keys = sort { $name{$a} cmp $name{$b} } keys %name;

foreach my $key (@keys) {
 if (!defined($free{$key})){$free{$key}=$capacity{$key};}
 if ($testmode eq "relative") {
  $usagefraction{$key} = $free{$key}/$capacity{$key}*100;
 } else {
  $usagefraction{$key} = $free{$key}/1024/1024/1024;
 }
}

#print "mode = $testmode\n";
if ( defined($o_storagename)) {
 my %rhash = reverse %name;
 my $key = $rhash{$o_storagename};
 if ($usagefraction{$key} < $o_crit) {
  #print "CRITICAL :";
  $state = "CRITICAL";
 } elsif ($usagefraction{$key} < $o_warn) {
  #print "WARNING :";
  $state = "WARNING";
 } else {
  #print "OK :";
  $state = "OK";
 }
 $output = $state." : ".$name{$key} . ": ".round($usagefraction{$key},1);
 if ($testmode eq "relative") {
  $output .= " %"
 } else {
  $output .= " GB"
 }
 $output .= " free.\n";
 print $output;
 exit $ERRORS{$state};
} else {
 foreach my $key (@keys) {
  if ($usagefraction{$key} < $o_crit) {
   $output .= "C->";
   $state = "CRITICAL";
  } elsif ($usagefraction{$key} < $o_warn) {
   $output .= "W->";
   if ($state ne "CRITICAL") { $state = "WARNING"; }
  } else {
   if (($state ne "CRITICAL")&&($state ne "WARNING")) { $state = "OK"; }
  }
  $output .= $name{$key} . "(".round($usagefraction{$key},1);
  if ($testmode eq "relative") {
   $output .= "%"
  } else {
   $output .= "GB"
  }
  $output .= ") ";
 }
 print $state ." : ".$output."\n";
 exit $ERRORS{$state};
}
