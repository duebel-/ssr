#!/usr/bin/perl

use Date::Parse;
use POSIX;
use VMware::VIFPLib;
use Getopt::Long;

$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0; #LWP shall not verify certs (default as of ver 6)

my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
my $state="";
my $output="";
my @old_snapshots = ();

sub check_options {
    Getopt::Long::Configure ("bundling");
    GetOptions(
        'h'     => \$o_help,            'help'          => \$o_help,
        'H:s'   => \$o_host,            'hostname:s'    => \$o_host,
        'c:s'   => \$o_crit,            'critical:s'    => \$o_crit,
        'w:s'   => \$o_warn,            'warn:s'        => \$o_warn,
        'a:s'   => \$o_age,             'age:s'         => \$o_age
    );
    if (defined($o_help) ) { help(); exit $ERRORS{"UNKNOWN"}};
    if ( ! defined($o_host) || !defined($o_warn) || !defined($o_crit)) { print_usage(); exit $ERRORS{"UNKNOWN"}};
    if ((isnnum($o_warn)) || (isnnum($o_crit))) { print " warn and crit must be numbers\n";print_usage(); exit $ERRORS{"UNKNOWN"}};
    # Check for positive numbers
    if (($o_warn < 0) || ($o_crit < 0)) { print " warn and critical > 0 \n";print_usage(); exit $ERRORS{"UNKNOWN"}};
    # Check warning and critical values
    if ($o_warn >= $o_crit) { print " warn < crit\n";print_usage(); exit $ERRORS{"UNKNOWN"}};
    # set default age value
    if ( !defined($o_age)){ $o_age = 0; };
    if (isnnum($o_age)) { print " age must be a number of days\n";print_usage(); exit $ERRORS{"UNKNOWN"}};
}

sub isnnum { # Return true if arg is not a number
  my $num = shift;
  if ( $num =~ /^-?(\d+\.?\d*)|(^\.\d+)$/ ) { return 0 ;}
  return 1;
}

sub check_age {
  my $date_created = shift;
  return(1) if ((time() - $date_created) > ($o_age * 86400));
  return(0);
}

sub check_snaplist {
  my $vm_name = shift;
  my $vm_snaptree = shift;
  foreach my $vm_snapshot (@{$vm_snaptree}) {
    my $date_snapshot = str2time($vm_snapshot->{createTime});
    next unless (check_age($date_snapshot));
    $old_snapshots[scalar(@old_snapshots)] = {
      'vm' => $vm_name,
      'age' => ceil(((time() - $date_snapshot)/86400)),
    };
  }
}

sub help {
   print "\nVMWare snapshot monitor for Nagios\n";
   print "(c)yes\n\n";
   print_usage();
   print <<EOT;
By default, plugin will monitor #snapshots:
warn if #snaphots > warn and critical if #snaphots > crit
-h, --help
   print this help message
-H, --hostname=HOST
   name or IP address of host to check
-a, --age=<n>
   min. age of snapshot in days
-w, --warn=<n>
   warning #
-c, --critical=<n>
   critical #

EOT
}

sub print_usage {
    print "Usage: $Name -H <host> [-a <days>] -w <warn_level> -c <crit_level>\n";
}

check_options();

my $vima_target = VmaTargetLib::query_target($o_host);
$vima_target->login();

my $vm = Vim::find_entity_views(view_type => 'VirtualMachine');

foreach my $vm_view (@{$vm}) {
  my $vm_name     = $vm_view->{summary}->{config}->{name};
  my $vm_snaptree = $vm_view->{snapshot};
  next unless ( defined $vm_snaptree && ($vm_view->runtime->powerState->val eq 'poweredOn') );
  check_snaplist($vm_name, $vm_snaptree->{rootSnapshotList});
}

if (scalar(@old_snapshots) > $o_warn){
  $output=scalar(@old_snapshots) . " snapshots found (";
  foreach my $old_snapshot (@old_snapshots){
    $output .= $old_snapshot->{'vm'} . "->" . $old_snapshot->{'age'} . "days, ";
  }
  $output =~ s/,\ $//;
  $output .= ")";
  if (scalar(@old_snapshots) > $o_crit){
    $state = "CRITICAL";
  } else {
    $state = "WARNING";
  }
}
else{
  $output = scalar(@old_snapshots) . " snapshots found.";
  $state="OK";
}

print $state ." : ".$output."\n";
exit $ERRORS{$state};
