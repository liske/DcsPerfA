#!/usr/bin/perl

use Chart::Gnuplot;
use Date::Parse;
use strict;
use warnings;

die "Usage: $0 <from> <to> <defs.csv> <data.csv> <output dir>\n" unless($#ARGV == 4);

use constant {
    GNUPLOT_TIME_OFFSET => 946684800,
};

my %groupings = (
    HMBytes => qr/(Hit|Miss)Bytes$/,
    HitsMisses => qr/(Hits|Misses)$/,
    Pending => qr/Pending/,
    Percent => qr/Percent/,
    Bytes => qr/.+Bytes.+/,
    Time => qr/Time$/,
    IOPs => qr/(Operations|Reads|Writes)$/,
    );

my ($from, $to, $fn_defs, $fn_data, $outdir) = @ARGV;
my $t1 = str2time($from);
my $t2 = str2time($to);
$outdir =~ s@/$@@;
die "Could not read definition file '$fn_defs'!\n" unless (-r $fn_defs);
die "Could not read data file '$fn_data'!\n" unless (-r $fn_data);
die "Output path '$outdir' is not a directory!\n" unless(-d $outdir);

print STDERR 'Filter range: ', scalar localtime($t1), ' - ', scalar localtime($t2), "\n";


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


print STDERR "Creating CSV data output...\n";
my $CSV = "$outdir/data.csv";
open(HOUT, '>', $CSV) || die "Could not create '$CSV': $!\n";
my @k1 = sort {$a <=> $b} keys %keys;
print HOUT '#TimeStamp';
my $idx = 2;
my %indexes;
my %mins;
my %maxs;
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
		    $v /= ($ts - $last);
		}
		else {
		    $v = '';
		}
	    }

	    if($v ne '') {
		my $group = $groupmap{$k1}->{$k2};
		$maxs{$group} = $v if(!exists($maxs{$group}) || $maxs{$group} < $v);
		$mins{$group} = $v if(!exists($mins{$group}) || $mins{$group} > $v);
	    }

	    print HOUT "\t$v";
	}
    }

    print HOUT "\n";

    $last = $ts;
}
close(HOUT);


print STDERR "Creating graphs...\n";
foreach my $type (sort keys %classes) {
    print STDERR "\n[$type]\n";
    foreach my $pi (sort keys %{$classes{$type}}) {
	print STDERR " + $pi\n";

	foreach my $group (sort keys %{ $classes{$type}->{$pi} }) {
	    my @dsets;
	    
	    print STDERR "   -";
	    foreach my $counter (sort keys %{$classes{$type}->{$pi}->{$group} }) {
		print STDERR " $counter";
		    
		unless($indexes{ $classes{$type}->{$pi}->{$group}->{$counter}->{k1} }->{ $classes{$type}->{$pi}->{$group}->{$counter}->{k2} }) {
		    print STDERR "[i]";
		    next;
		}

		my $i = $indexes{ $classes{$type}->{$pi}->{$group}->{$counter}->{k1} }->{ $classes{$type}->{$pi}->{$group}->{$counter}->{k2} };
		if($group =~ /Time/) {
		    $i = "(\$$i/1000000)";
		}
		push(@dsets, Chart::Gnuplot::DataSet->new(
			 datafile => $CSV,
			 using => "1:$i smooth csplines",
			 title => $counter,
			 style => 'lines lw 2',
		     ));
	    }
	    if($#dsets == -1 || $mins{$group} == $maxs{$group}) {
		print STDERR " SKIPPED\n";
		next;
	    }
	    print STDERR "\n";
	    
	    my $out = "$outdir/$type-$pi-$group.png";
	    $out =~ s/ /_/g;
	    
	    unlink($out);
	    my $chart = Chart::Gnuplot->new(
		output => $out,
		title => $pi,
		timefmt => '"%s"',
		xdata => 'time',
		bg => 'white',
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
	    $chart->command('set format x "%y/%m/%d"');
	    if($group =~ /Byte/) {
		$chart->command('set format y "%.1s %cb"');
	    }
	    elsif($group =~ /Time/) {
		$chart->command('set format y "%.1s %cs"');
	    }
	    elsif($group =~ /Percent/) {
		$chart->command('set format y "%.1s %%"');
	    }
	    elsif($group =~ /IOPs/) {
		$chart->command('set format y "%.1s %cops"');
	    }
	    else {
		$chart->command('set format y "%.1s %c"');
	    }
	    eval('$chart->plot2d(@dsets);');
	}
    }
}
