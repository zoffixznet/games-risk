use 5.010;
use strict;
use warnings;

package Games::Risk::Map;
# ABSTRACT: map being played

use Hash::NoRef;
use List::Util      qw{ shuffle };
use List::MoreUtils qw{ uniq };
use Moose;
use MooseX::Has::Sugar;
use MooseX::SemiAffordanceAccessor;

use Games::Risk::Logger qw{ debug };
use Games::Risk::Utils  qw{ $SHAREDIR };


# -- attributes

=attr continents

=attr cards

A L<Games::Risk::Deck> object holding the cards.

=cut

has continents => (
    ro, lazy_build, auto_deref,
    isa => 'ArrayRef[Games::Risk::Continent]',
);

has cards => ( ro, lazy_build, isa => 'Games::Risk::Deck' );

# a hash containing weak references (thanks Hash::NoRef) to prevent
# circular references to lock memory
has _countries => (
    ro, lazy_build,
    isa     =>'HashRef',
    traits  => [ 'Hash' ],
    handles => {
        countries    => 'values',
        country_get  => 'get',
        _country_set => 'set',
    },
);


# -- initializers & finalizers

sub DEMOLISH {  debug( "~map " . $_[0]->name ."\n" ) }

sub _build_continents {
    my $self = shift;
    require Games::Risk::Continent;
    require Games::Risk::Country;

    my @continents;

    foreach my $raw ( $self->_raw_continents ) {
        # create the continent
        my ($id, $name, $bonus, $color) = @$raw;
        debug( "new continent: $name\n" );
        my $continent = Games::Risk::Continent->new( {
                id    => $id,
                name  => $name,
                bonus => $bonus,
                color => $color,
                map   => $self,
            } );
        push @continents, $continent;

        # populate the continent with the countries
        my @raw_countries = grep { $_->[2] == $id } $self->_raw_countries;
        my @countries;
        foreach my $rawc ( @raw_countries ) {
            # create the country
            my ($id, $name, undef, $x, $y, $connections) = @$rawc;
            debug( "new country: $name\n" );
            my $country = Games::Risk::Country->new( {
                    greyval     => $id,
                    name        => $name,
                    coordx      => $x,
                    coordy      => $y,
                    continent   => $continent,
                    connections => $connections,
                } );
            push @countries, $country;

            # store a cached value without increasing hash ref
            $self->_country_set( $id => $country );
        }
        $continent->set_countries( \@countries );
    }

    return \@continents;
}

sub _build_cards {
    my $self = shift;
    require Games::Risk::Card;
    require Games::Risk::Deck;

    my @cards;
    foreach my $raw ( $self->_raw_cards ) {
        my ($type, $c) = @$raw;
        my $card = Games::Risk::Card->new( { type => $type } );
        $card->set_country( $self->country_get($c) ) if defined $c;
        push @cards, $card;
    }
    my $deck = Games::Risk::Deck->new( { cards => \@cards } );
    return $deck;
}

sub _build__countries {
    my %hash ;
    tie %hash , 'Hash::NoRef';
    return \%hash;
}


# -- class methods

=method name

    my $name = Games::Risk::Map::Foobar->name;

The short map identifier, needs to be overriden by sub-classes.

=method title

    my $title = Games::Risk::Map::Foobar->title;

The map title, needs to be overriden by sub-classes.

=attr author

    my $author = Games::Risk::Map::Foobar->author;

The map author, needs to be overriden by sub-classes.

=cut

sub name   { die "name needs to be overriden" }
sub title  { die "title needs to be overriden" }
sub author { die "author needs to be overriden" }


# -- public methods

=method sharebase

    my $dir = $self->sharebase;

Return the path to the base share directory to use (either the
games-risk one, or one of the extra maps dists).

=cut

sub sharebase { $SHAREDIR }

=method sharedir

    my $dir = $map->sharedir;

Return the path to the private directory holding the map files.

=cut

sub sharedir { return $_[0]->sharebase->subdir( 'maps', $_[0]->name ); }


=method localedir

    my $dir = $map->localedir;

Return the path to the private directory holding the locale files.

=cut

sub localedir { return $_[0]->sharebase->subdir("locale"); }


=method background

    my $bgpath = $map->background;

Return the path to the background image for the board.

=cut

sub background {
    my $self = shift;
    my ($bg) = grep { /background/ } $self->sharedir->children;
    return $bg->stringify;
}


=attr greyscale

    my $gspath = $map->greyscale;

The path to the greyscale bitmap for the board.

=cut

sub greyscale {
    my $self = shift;
    my ($gs) = grep { /greyscale/ } $self->sharedir->children;
    return $gs->stringify;
}


=method continents_owned

    my @owned = $map->continents_owned;

Return a list with all continents that are owned by a single player.

=cut

sub continents_owned {
    my $self = shift;

    my @owned = ();
    foreach my $continent ( $self->continents ) {
        my $nb = uniq map { $_->owner } $continent->countries;
        push @owned, $continent if $nb == 1;
    }
    return @owned;
}


=method countries

    my @countries = $map->countries;

Return the list of all countries in the C<$map>.

=method country_get

    my $country = $map->country_get($id);

Return the country which id matches C<$id>.

=cut

# provided for free by handlers of _countries attribute


__PACKAGE__->meta->make_immutable;
1;
__END__

=for Pod::Coverage
    DEMOLISH


=head1 DESCRIPTION

This module implements a map, pointing to the continents, the
countries, etc. of the game currently in play.

