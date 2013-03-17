#!/usr/bin/perl

use Date::Parse;
use strict;
use warnings;

die "Usage: $0 <from> <to> <defs.csv> <data.csv>\n" unless($#ARGV == 3);

my ($from, $to, $fn_defs, $fn_data) = @ARGV;
my $t1 = str2time($from);
my $t2 = str2time($to);
print STDERR 'Filter range: ', scalar localtime($t1), ' - ', scalar localtime($t2), "\n";


print STDERR "Reading definitions...\n";
my %names;
open(HDEFS, $fn_defs) || die;
while(<HDEFS>) {
    chomp;
    my ($k1, $k2, $class, $short, $long, $metric, $type) = split(/[,\t]/);
    $names{$k1}->{$k2} = "$long:$metric";
}
close(HDEFS);


print STDERR "Reading input...\n";
my %vals;
my %keys;
my $key;
open(HDATA, $fn_data) || die;
while(<HDATA>) {
    chomp;
    my ($ts, $k1, $k2, $data) = split(/[,\t]/);
    $ts = int($ts/10000 + 0.5)*10;

    next unless($ts >= $t1 && $ts <= $t2);

    $vals{$ts}->{$k1}->{$k2} = $data;
    $keys{$k1}->{$k2}++;
}
close(HDATA);


print STDERR "Dumping output...\n";
my @k1 = sort {$a <=> $b} keys %keys;
print 'TimeStamp';
foreach my $k1 (@k1) {
    foreach my $k2 (sort {$a <=> $b} keys %{$keys{$k1}}) {
	print "\t$names{$k1}->{$k2}";
    }
}
print "\n";

foreach my $ts (sort {$a <=> $b} keys %vals) {
    print $ts;

    foreach my $k1 (@k1) {
	foreach my $k2 (sort {$a <=> $b} keys %{$keys{$k1}}) {
	    print "\t", $vals{$ts}->{$k1}->{$k2};
	}
    }

    print "\n";
}
