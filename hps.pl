#!perl

use strict;
use warnings;
use utf8;
use LWP::UserAgent;

sub main {
    my ($playlist_url) = @_;

    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);

    my %previous_data_source_bag;

    my $response = $ua->get($playlist_url);
    if ($response->is_success) {
        my $serialized_lines = $response->decoded_content;
        my @lines = split /\r?\n/, $serialized_lines;
        my %data_source_bag = %{extract_data_source_bag(\@lines)};
        %previous_data_source_bag = %data_source_bag;
        print $serialized_lines;
    }
    else {
        die $response->status_line;
    }

    while (1) {
        my $response = $ua->get($playlist_url);
        if ($response->is_success) {
            my $serialized_lines = $response->decoded_content;
            my @lines = split /\r?\n/, $serialized_lines;
            my $targetduration = extract_targetduration(\@lines);

            if (!defined $targetduration) {
                die 'Invalid playlist';
            }

            my %data_source_bag = %{extract_data_source_bag(\@lines)};

            if (%previous_data_source_bag) {
                for my $key (keys %previous_data_source_bag) {
                    delete $data_source_bag{$key};
                }
            }

            for my $key (sort {$a cmp $b} keys %data_source_bag) {
                print "$data_source_bag{$key}\n$key\n";
            }

            %previous_data_source_bag = %data_source_bag;

            sleep $targetduration;
        }
        elsif ($response->code == 404) {
            last;
        }
        else {
            die $response->status_line;
        }
    }
}

sub extract_targetduration {
    my ($lines) = @_;

    for my $line (@$lines) {
        chomp $line;
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
        chomp $line;

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

