#!perl

use strict;
use warnings;
use utf8;

sub main {
    my ($playlist_url) = @_;

    local $| = 1;

    my ($response, $status) = curl_get($playlist_url);
    if ($status != 0) {
        die $response;
    }

    my @lines = split /\r?\n/, $response;
    my %previous_data_source_bag = %{extract_data_source_bag(\@lines)};
    print $response;

    while (1) {
        my ($response, $status) = curl_get($playlist_url);
        if ($status == 0) {
            my @lines = split /\r?\n/, $response;
            my $targetduration = extract_targetduration(\@lines);

            if (!defined $targetduration) {
                die 'Invalid playlist';
            }

            my %data_source_bag_orig = %{extract_data_source_bag(\@lines)};
            my %data_source_bag = %data_source_bag_orig;

            for my $key (keys %previous_data_source_bag) {
                delete $data_source_bag{$key};
            }

            for my $key (sort {$a cmp $b} keys %data_source_bag) {
                print "$data_source_bag{$key}\n$key\n";
            }

            %previous_data_source_bag = %data_source_bag_orig;

            sleep $targetduration;
        }
        elsif ($response =~ /404 Not Found/) {
            last;
        }
        else {
            die $response;
        }
    }
}

sub curl_get {
    my ($url) = @_;

    my @opt = qw{
      --location
      --silent
      --show-error
      --user-agent 'hls-playlist-snatcher:0.0.1'
    };
    my $response = `curl @opt -- $url`;

    return ($response, $?);
}

sub extract_targetduration {
    my ($lines) = @_;

    for my $line (@$lines) {
        if ($line =~ /\A#EXT-X-TARGETDURATION:(.+)\Z/) {
            return $1;
        }
    }
}

sub extract_data_source_bag {
    my ($lines) = @_;

    my %data_source_bag;

    my $line_num = scalar @$lines;
    for (my $i = 0; $i < $line_num; $i++) {
        my $line = $lines->[$i];
        if ($line =~ /\A#EXTINF:.+\Z/) {
            my $extinf = $line;
            while (++$i < $line_num) {
                if ($line = $lines->[$i]) {
                    $data_source_bag{$line} = $extinf;
                    last;
                }
            }
        }
    }

    return \%data_source_bag;
}

my $playlist_url = shift;
if (!defined $playlist_url) {
    die <<EOS;
[ERROR] Missing playlist URL.
Usage:
    perl hps.pl <playlist URL>
EOS
}

main($playlist_url);

__END__

