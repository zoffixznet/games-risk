use 5.010;
use strict;
use warnings;

package Games::Risk::Logger;
# ABSTRACT: logging capacities for prisk

use Exporter::Lite;
use FindBin         qw{ $Bin };
use Path::Class;
use Term::ANSIColor qw{ :constants };
use Text::Padding;
 
our @EXPORT_OK = qw{ debug };


=method debug( @stuff );

Output C<@stuff> on stderr if we're in a local git checkout. Do nothing
in regular builds.

=cut

my $debug = -d dir($Bin)->parent->subdir('.git');
my $pad   = Text::Padding->new;
sub debug {
    return unless $debug;
    my ($pkg, $filename, $line) = caller;
    $pkg =~ s/^Games::Risk:://g;
    # BLUE and YELLOW have a length of 5. RESET has a length of 4
    my $prefix = $pad->right( BLUE . $pkg . YELLOW . ":$line" . RESET, 40);
    warn "$prefix @_";
}


1;
__END__

=head1 SYNOPSIS

    use Games::Risk::Logger qw{ debug };
    debug( "useful stuff" );

=head1 DESCRIPTION

This module provides some logging capacities to be used within prisk.

