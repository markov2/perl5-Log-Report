package Dancer2::Logger::LogReport;
# ABSTRACT: Dancer2 logger engine for Log::Report

use strict;
use warnings;

use Moo;
use Dancer2::Core::Types;
use Scalar::Util qw/blessed/;
use Log::Report  'logreport', syntax => 'REPORT', mode => 'DEBUG';

our $AUTHORITY = 'cpan:MARKOV';

# all dispatchers shall be created exactly once (unique name)
my %disp_objs;

my %level_dancer2lr =
  ( core  => 'TRACE'
  , debug => 'TRACE'
  );

with 'Dancer2::Core::Role::Logger';

# Set by calling function
has dispatchers =>
  ( is    => 'ro'
  , isa   => Maybe[HashRef]
  , lazy  => 1
  );

sub BUILD ()
{   my $self     = shift;
    my $configs  = $self->dispatchers || {default => undef};
    $self->{use} = [keys %$configs];

    foreach my $name (keys %$configs)
    {   my $config = $configs->{$name} || {};
        if(keys %$config)
        {   # cannot use log() output yet!  recursion!
            ! $disp_objs{$name}
                or die "attempt to reconfigure dispatcher $name";

            my $type = delete $config->{type}
                or die "dispatcher configuration $name without type";

            $disp_objs{$name} = dispatcher $type, $name, %$config;
        }
    }
}

=chapter NAME

Dancer2::Logger::LogReport - reroute Dancer2 logs into Log::Report

=chapter SYNOPSIS

  # This module is loaded when configured.  It does not provide
  # end-user functions or methods.

  # See L<Dancer2::Plugin::LogReport/"DETAILS">
  
=chapter DESCRIPTION

[The Dancer2 plugin was contributed by Andrew Beverley]

This logger allows the use of the many logging backends available
in M<Log::Report>.  It will process all of the Dancer2 log messages,
and also allow any other module to use the same logging facilities. The
same log messages can be sent to multiple destinations at the same time
via flexible dispatchers.

If using this logger, you may also want to use
M<Dancer2::Plugin::LogReport>

Many log back-ends, like syslog, have more levels of system messages.
Modules who explicitly load this module can use the missing C<assert>,
C<notice>, C<panic>, and C<alert> log levels.  The C<trace> name is
provided as well: when you are debugging, you add a 'trace' to your
program... it's just a better name than 'debug'.

You probably want to set a very simple C<logger_format>, because the
dispatchers do already add some of the fields that the default C<simple>
format adds.  For instance, to get the filename/line-number in messages
depends on the dispatcher 'mode' (f.i. 'DEBUG').

You also want to set the log level to C<debug>, because level filtering is
controlled per dispatcher (as well).

See L<Dancer2::Plugin::LogReport/"DETAILS"> for examples.

=chapter METHODS

=method log $level, $params

=cut

sub log($$$)
{   my ($self, $level, $params) = @_;

    # all dancer levels are the same as L::R levels, except:
    my $msg;
    if(blessed $params && $params->isa('Log::Report::Message'))
    {   $msg = $params;
    }
    else
    {   $msg = $self->format_message($level => $params);
        $msg =~ s/\n+$//;
    }

    # the levels are nearly the same.
    my $reason = $level_dancer2lr{$level} // uc $level;

    report {is_fatal => 0}, $reason => $msg, to => $self->{use};

    undef;
}
 
1;
