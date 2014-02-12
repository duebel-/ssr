#!/usr/bin/perl
#
# ldif2csv.pl
#
# Writes CSV file to STDOUT based on LDIF file
#
# If you have comment on my code, please drop me a note.
# You can find my email at http://www.painfullscratch.nl
#
#

if(scalar(@ARGV) != 1) {
        print STDERR "Usage: $0 <ldiffile>\n";
        exit(1);
}

my $filename = $ARGV[0];
my %fields;

open(FILE, " < $filename") or die("Can't open $filename: ".$@);
my @content = <FILE>;
close(FILE);

# determine all used fields in ldif file ...
foreach (@content) {
        if(/^# search result$/) {
                last;
        }
        elsif(/^(?!# )(.+): .+$/) {
                my $fieldname = $1;
                $fields{$fieldname} = undef;
        }
}

print join(";", sort keys %fields )."\n";

my %lfields = ();

foreach (@content) {
        my $line = $_;
        $_ = $line;
        if(/^# search result$/) {
                last;
        }
        elsif(/^(?!# )(.+): (.+)$/) {
                my $fieldname = $1;
                my $value = $2;
                push(@{$lfields{$fieldname}},$value);
        }
        elsif(/^$/) {
                if(defined $lfields{'dn'}) {
                        foreach my $fieldname ( sort keys %fields ) {
                                print '"'.join(",",@{$lfields{$fieldname}}).'";';
                        }
                        print "\n";
                        %lfields = ();
                }
        }
}

exit;
