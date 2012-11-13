#!./perl -w

# Test that CUSTOMIZED files in Maintainers.pl have not been overwritten.

BEGIN {
        # This test script uses a slightly atypical invocation of the 'standard'
        # core testing setup stanza.
        # The existing porting tools which manage the Maintainers file all
        # expect to be run from the root
        # XXX that should be fixed

    chdir '..' unless -d 't';
    @INC = qw(lib Porting);
}

use strict;
use warnings;
use Digest;
use File::Spec;
use Maintainers qw[%Modules get_module_files get_module_pat];

sub filter_customized {
    my ($m, @files) = @_;

    return @files
        unless my $customized = $Modules{$m}{CUSTOMIZED};

    my ($pat) = map { qr/$_/ } join '|' => map {
        ref $_ ? $_ : qr/\b\Q$_\E$/
    } @{ $customized };

    return grep { $_ =~ $pat } @files;
}

sub my_get_module_files {
    my $m = shift;
    return filter_customized $m => map { Maintainers::expand_glob($_) } get_module_pat($m);
}

my $TestCounter = 0;

my $digest_type = 'SHA-1';

my $original_dir = File::Spec->rel2abs(File::Spec->curdir);
my $data_dir = File::Spec->catdir('t', 'porting');
my $customised = File::Spec->catfile($data_dir, 'customized.dat');

my %customised;

my $regen = 0;

while (@ARGV && substr($ARGV[0], 0, 1) eq '-') {
    my $arg = shift @ARGV;

    $arg =~ s/^--/-/; # Treat '--' the same as a single '-'
    if ($arg eq '-regen') {
        $regen = 1;
    }
    else {
        die <<EOF;
Unknown option '$arg'

Usage: $0 [ --regen ]\n"
    --regen    -> Regenerate the data file for $0

EOF
    }
}

my $data_fh;

if ( $regen ) {
  open $data_fh, '>:bytes', $customised or die "Can't open $customised";
}
else {
  open $data_fh, '<:bytes', $customised or die "Can't open $customised";
  while (<$data_fh>) {
    chomp;
    my ($module,$file,$sha) = split ' ';
    $customised{ $module }->{ $file } = $sha;
  }
  close $data_fh;
}

foreach my $module ( keys %Modules ) {
  next unless my $files = $Modules{ $module }{CUSTOMIZED};
  my @perl_files = my_get_module_files( $module );
  foreach my $file ( @perl_files ) {
    my $digest = Digest->new( $digest_type );
    {
      open my $fh, '<', $file or die "Can't open $file";
      binmode $fh;
      $digest->addfile( $fh );
      close $fh;
    }
    my $id = $digest->hexdigest;
    if ( $regen ) {
      print $data_fh join(' ', $module, $file, $id), "\n";
      next;
    }
    my $should_be = $customised{ $module }->{ $file };
    if ( $id ne $should_be ) {
       print  "not ok ".++$TestCounter." - SHA for $file does not match stashed SHA\n";
    }
    else {
       print  "ok ".++$TestCounter." - SHA for $file matched\n";
    }
  }
}

if ( $regen ) {
  print "ok ".++$TestCounter." - regenerated data file\n";
  close $data_fh;
}

print "1..".$TestCounter."\n";

=pod

=head1 NAME

customized.t - Test that CUSTOMIZED files in Maintainers.pl have not been overwritten

=head1 SYNOPSIS

 cd t
 ./perl -I../lib porting/customized.t --regen

=head1 DESCRIPTION

customized.t checks that files listed in C<Maintainers.pl> that have been C<CUSTOMIZED>
are not accidently overwritten by CPAN module updates.

=head1 OPTIONS

=over

=item C<--regen>

Use this command line option to regenerate the C<customized.dat> file.

=back

=cut
