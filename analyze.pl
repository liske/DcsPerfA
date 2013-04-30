#!/usr/bin/perl

# DcsPerfA - DataCore Server Performance Analyzer
#
# Authors:
#   Thomas Liske <thomas@fiasko-nw.net>
#
# Copyright Holder:
#   2013 (C) Thomas Liske [http://fiasko-nw.net/~thomas/]
#
# License:
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this package; if not, write to the Free Software
#   Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
#

use Chart::Gnuplot;
use Date::Parse;
use File::Spec;
use JSON;
use Statistics::Basic qw(:all);
use strict;
use warnings;

die "Usage: $0 <from> <to> <defs.csv> <data.csv> <output dir> [name]\n" unless($#ARGV == 4);

use constant {
    GNUPLOT_TIME_OFFSET => 946684800,
    IGNORE => 'IGNORE',
};

my %groupings = (
    HMBytes => qr/(Hit|Miss)Bytes$/,
    HitsMisses => qr/(Hits|Misses)$/,
    Pending => qr/Pending/,
    Percent => qr/Percent/,
    Bytes => qr/.+Bytes.+/,
    Time => qr/Time$/,
    IOPs => qr/(Operations|Reads|Writes)$/,
    IGNORE => qr/^Bytes/,
    );

my ($from, $to, $fn_defs, $fn_data, $outdir, $rname) = @ARGV;
my $t1 = str2time($from);
my $t2 = str2time($to);
die "Could not read definition file '$fn_defs'!\n" unless (-r $fn_defs);
die "Could not read data file '$fn_data'!\n" unless (-r $fn_data);

$rname = $rname || 'run1';

$outdir =~ s@/$@@;
mkdir($outdir);
mkdir("$outdir/img");
mkdir("$outdir/img/$rname");
mkdir("$outdir/raw");
mkdir("$outdir/raw/$rname");
die "Output path '$outdir' is not a directory!\n" unless(-d $outdir);

print STDERR "Name: $rname\n";
print STDERR 'Filter range: ', scalar localtime($t1), ' - ', scalar localtime($t2), "\n";
print STDERR "Output directory: $outdir\n\n";

# save meta data
my $META = "$outdir/raw/$rname/meta.json";
open(HMETA, '>', $META) || die "Could not create '$META': $!\n";
print HMETA to_json({
    cmdline => join(' ', $0, @ARGV),
    ffrom_ut => $t1,
    ffrom_lt => scalar localtime($t1),
    fto_ut => $t2,
    fto_lt => scalar localtime($t2),
}, {allow_blessed => 1, convert_blessed => 1, pretty => 1});
close(HMETA);

# read definitions from export
print STDERR "Reading definitions...\n";
my %classes;
my %names;
my %deltas;
my %groupmap;
open(HDEFS, $fn_defs) || die "Could not open '$fn_defs': $!\n";
while(<HDEFS>) {
    chomp;
    my ($k1, $k2, $type, $pishort, $pilong, $counter, $ctype) = split(/[,\t]/);
    die if(exists($names{$k1}) && exists($names{$k1}->{$k2}));
    $names{$k1}->{$k2} = "$pilong:$counter";

    my $group = $counter;
    foreach my $g (keys %groupings) {
	if($counter =~ $groupings{$g}) {
	    $group = $g;
	    last;
	}
    }

    next if($group eq IGNORE);

    $classes{$type}->{$pilong}->{$group}->{$counter} = {
	counter => $counter,
	ctype => $ctype,
	k1 => $k1,
	k2 => $k2,
    };

    $deltas{$k1}->{$k2}++ if($ctype eq 'Delta');
    $groupmap{$k1}->{$k2} = $group;
}
close(HDEFS);


# read data from export
print STDERR "Reading data...\n";
my %vals;
my %keys;
my $key;
open(HDATA, $fn_data) || die "Could not open '$fn_data': $!\n";
while(<HDATA>) {
    chomp;
    s/\r//;
    my ($ts, $k1, $k2, $data) = split(/[,\t]/);
    $ts = int($ts/10000 + 0.5)*10;

    next unless($ts >= $t1 && $ts <= $t2);

    $vals{$ts}->{$k1}->{$k2} = $data;
    $keys{$k1}->{$k2}++;
}
close(HDATA);


# create CSV data file and track some statistics
print STDERR "Creating CSV data output...\n";
my $CSV = "$outdir/raw/$rname/data.csv";
open(HOUT, '>', $CSV) || die "Could not create '$CSV': $!\n";
my @k1 = sort {$a <=> $b} keys %keys;
print HOUT '#TimeStamp';
my $idx = 2;
my %indexes;
my %mins;
my %maxs;
my %vectors;
foreach my $k1 (@k1) {
    foreach my $k2 (sort {$a <=> $b} keys %{$keys{$k1}}) {
	print HOUT "\t$names{$k1}->{$k2}";
	$indexes{$k1}->{$k2} = $idx++;
	print HOUT '_'.$indexes{$k1}->{$k2};
    }
}
print HOUT "\n";

my $last;
foreach my $ts (sort {$a <=> $b} keys %vals) {
    print HOUT $ts;

    foreach my $k1 (@k1) {
	foreach my $k2 (sort {$a <=> $b} keys %{$keys{$k1}}) {

	    my $v = $vals{$ts}->{$k1}->{$k2};

	    if($deltas{$k1}->{$k2}) {
		if(defined($last)) {
		    $v /= $ts - $last;
		}
		else {
		    $v = '';
		}
	    }

	    if($v ne '') {
		my $group = $groupmap{$k1}->{$k2};

		next unless(defined($group));

		# normalize time values
		$v /= 1000000 if($group =~ /Time/);

		$maxs{$group} = $v if(!exists($maxs{$group}) || $maxs{$group} < $v);
		$mins{$group} = $v if(!exists($mins{$group}) || $mins{$group} > $v);

		# track statistics
		unless(exists($vectors{$k1}->{$k2})) {
		    $vectors{$k1}->{$k2} = vector($v);
		}
		else {
		    $vectors{$k1}->{$k2}->append($v);
		}
	    }

	    print HOUT "\t$v";
	}
    }

    print HOUT "\n";

    $last = $ts;
}
close(HOUT);


# create graph drawings
print STDERR "Creating graphs...\n";

sub setformat($$$$) {
    my($group, $chart, $ctype, $axis) = @_;

    my $ps = ($ctype eq 'Delta' ? '/s' : '');

    if($group =~ /Byte/) {
	$chart->command("set format $axis \"%.1s %cb$ps\"");
    }
    elsif($group =~ /Time/) {
	$chart->command("set format $axis \"%.1s %cs$ps\"");
    }
    elsif($group =~ /Percent/) {
	$chart->command("set format $axis \"%.1s %%$ps\"");
    }
    elsif($group =~ /IOPs/) {
	$chart->command("set format $axis \"%.1s %cIO$ps\"");
    }
    else {
	$chart->command("set format $axis \"%.1s %c$ps\"");
    }
}

my %json;
foreach my $type (sort keys %classes) {
    print STDERR "\n[$type]\n";

    foreach my $pi (sort keys %{$classes{$type}}) {
	print STDERR " + $pi\n";

	foreach my $group (sort keys %{ $classes{$type}->{$pi} }) {
	    # ignore empty groups
	    next unless(defined($mins{$group}));
	    next if($mins{$group} == 0 && $maxs{$group} == 0);

	    my @dsets;
	    my @dsets_hist;
	    my $ctype;

	    print STDERR "   -";
	    foreach my $counter (sort keys %{$classes{$type}->{$pi}->{$group} }) {
		my $k1 = $classes{$type}->{$pi}->{$group}->{$counter}->{k1};
		my $k2 = $classes{$type}->{$pi}->{$group}->{$counter}->{k2};
		$ctype = $classes{$type}->{$pi}->{$group}->{$counter}->{ctype};
		print STDERR " $counter";

		unless($indexes{ $k1 }->{ $k2 }) {
		    print STDERR "[i]";
		    next;
		}

		unless(exists($vectors{ $k1 }->{ $k2 })) {
		    print STDERR "[e]";
		    next;
		}

		my $i = $indexes{ $k1 }->{ $k2 };
		push(@dsets, Chart::Gnuplot::DataSet->new(
			 datafile => $CSV,
			 using => "1:$i smooth csplines",
			 title => $counter,
			 style => 'lines lw 3',
		     ));
		push(@dsets_hist, Chart::Gnuplot::DataSet->new(
			 datafile => $CSV,
			 using => "(hist(\$$i,width)):(100.0/$keys{$k1}->{$k2}) smooth freq",
			 title => $counter,
			 style => 'steps lw 3',
		     ));

		%{ $json{$type}->{$pi}->{$group}->{Counters}->{$counter} } = %{ $classes{$type}->{$pi}->{$group}->{$counter} };
		$json{$type}->{$pi}->{$group}->{Counters}->{$counter}->{stats}->{mean} = mean( $vectors{$k1}->{$k2} )->query;
		$json{$type}->{$pi}->{$group}->{Counters}->{$counter}->{stats}->{median} = median( $vectors{$k1}->{$k2} )->query;
		$json{$type}->{$pi}->{$group}->{Counters}->{$counter}->{stats}->{var} = var( $vectors{$k1}->{$k2} )->query;
		$json{$type}->{$pi}->{$group}->{Counters}->{$counter}->{stats}->{stddev} = stddev( $vectors{$k1}->{$k2} )->query;
	    }
	    if($#dsets == -1) {
		print STDERR " SKIPPED\n";
		next;
	    }
	    print STDERR "\n";
	    

	    my $out = "$type-$pi-${group}_trend.png";
	    $out =~ s/ /_/g;
	    $out = "$outdir/img/$rname/$out";
	    
	    unlink("$out");
	    my $chart = Chart::Gnuplot->new(
		output => "$out",
		title => "$pi (trend)",
		timefmt => '"%s"',
		xdata => 'time',
#		bg => 'white',
		legend => {
		    position => 'below',
		},
		xrange => [$t1 - GNUPLOT_TIME_OFFSET, $t2 - GNUPLOT_TIME_OFFSET],
		yrange => [($mins{$group} < 0 ? $mins{$group}*1.1 : 0), $maxs{$group}*1.1],
		grid => {
		    width => 1,
		},
		tics => 'out',
		);

	    setformat($group, $chart, $ctype, 'y');

	    eval('$chart->plot2d(@dsets);');
	    $json{$type}->{$pi}->{$group}->{Images}->{trend} = File::Spec->abs2rel($out, $outdir);


	    $out = "$type-$pi-${group}_hist.png";
	    $out =~ s/ /_/g;
	    $out = "$outdir/img/$rname/$out";

	    unlink("$out");
	    my $cwidth = abs($maxs{$group}*1.0 - $mins{$group}*1.0)/100;
	    my $chart_hist = Chart::Gnuplot->new(
		output => "$out",
		title => "$pi (histogram; bin-width = $cwidth)",
#		bg => 'white',
		legend => {
		    position => 'below',
		},
		xrange => [($mins{$group} < 0 ? $mins{$group} : 0), $maxs{$group}],
		yrange => [0, 100],
		grid => {
		    width => 1,
		},
		tics => 'out',
		);

	    setformat($group, $chart_hist, $ctype, 'x');
	    $chart_hist->command("set format y \"%.1s %%\""); #"

	    $chart_hist->command("width=$cwidth");
	    $chart_hist->command('hist(x,width)=width*floor(x/width)+width/2.0');

	    eval('$chart_hist->plot2d(@dsets_hist);');
	    $json{$type}->{$pi}->{$group}->{Images}->{histogram} = File::Spec->abs2rel($out, $outdir);
	}
    }
}


# save counter data
my $COUNTERS = "$outdir/raw/$rname/counters.json";
open(HCOUNTERS, '>', $COUNTERS) || die "Could not create '$COUNTERS': $!\n";
print HCOUNTERS to_json(\%json, {allow_blessed => 1, convert_blessed => 1, pretty => 1});
close(HCOUNTERS);


# update/create manifest
my $fn_mani = "$outdir/raw/manifest.json";
my $manifest = { };
if (open(HMANI, '<', $fn_mani)) {
    $manifest = decode_json(join('', <HMANI>));
    close(HMANI);
}

$manifest->{$rname} = time;
open(HMANI, '>', $fn_mani) || die "Could not create '$fn_mani': $!\n";
print HMANI to_json($manifest, {allow_blessed => 1, convert_blessed => 1, pretty => 1});
close(HMANI);
