use warnings;
use strict;

package Log::Report::Dispatcher::Perl;
use base 'Log::Report::Dispatcher';

use Log::Report 'log-report', syntax => 'SHORT';
use IO::File;

my $singleton = 0;   # can be only one (per thread)

=chapter NAME
Log::Report::Dispatcher::Perl - send messages to die and warn

=chapter SYNOPSIS
 dispatcher Log::Report::Dispatcher::Perl => 'default'
   , accept => 'NOTICE-';

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

sub log($$$)
{   my ($self, $opts, $reason, $message) = @_;
    my $text = $self->SUPER::translate($opts, $reason, $message);

    if($opts->{is_fatal})
    {   $! = $opts->{errno};
        die $text;
    }
    else
    {   warn $text;
    }
}

1;
