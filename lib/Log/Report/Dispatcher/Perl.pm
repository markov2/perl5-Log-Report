#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

# This code is part of distribution Log-Report. Meta-POD processed with
# OODoc into POD and HTML manual-pages.  See README.md
# Copyright Mark Overmeer.  Licensed under the same terms as Perl itself.

package Log::Report::Dispatcher::Perl;
use base 'Log::Report::Dispatcher';

use warnings;
use strict;

use Log::Report 'log-report';

my $singleton = 0;   # can be only one (per thread)

#--------------------
=chapter NAME
Log::Report::Dispatcher::Perl - send messages to die and warn

=chapter SYNOPSIS
  dispatcher Log::Report::Dispatcher::Perl => 'default',
    accept => 'NOTICE-';

  # close the default dispatcher
  dispatcher close => 'default';

=chapter DESCRIPTION

Ventilate the problem reports via the standard Perl error mechanisms:
C<die()>, C<warn()>, and C<print()>.  There can be only one such dispatcher
(per thread), because once C<die()> is called, we are not able to return.
Therefore, this dispatcher will always be called last.

In the early releases of Log::Report, it tried to simulate the behavior
of warn and die using STDERR and exit; however: that is not possible.

=chapter METHODS

=section Constructors

=section Accessors

=section Logging
=cut

sub log($$$$)
{	my ($self, $opts, $reason, $message, $domain) = @_;
	print STDERR $self->translate($opts, $reason, $message);
}

1;
