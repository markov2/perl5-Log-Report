use warnings;
use strict;

package Log::Report::Dispatcher::Log4perl;
use base 'Log::Report::Dispatcher';

use Log::Report 'log-report';

use Log::Report::Util qw/@reasons expand_reasons/;
use Log::Log4perl     qw/:levels/;

my %default_reasonToLevel =
 ( TRACE   => $DEBUG
 , ASSERT  => $DEBUG
 , INFO    => $INFO
 , NOTICE  => $INFO
 , WARNING => $WARN
 , MISTAKE => $WARN
 , ERROR   => $ERROR
 , FAULT   => $ERROR
 , ALERT   => $FATAL
 , FAILURE => $FATAL
 , PANIC   => $FATAL
 );

@reasons==keys %default_reasonToLevel
    or panic __"Not all reasons have a default translation";

=chapter NAME
Log::Report::Dispatcher::Log4perl - send messages to Log::Log4perl back-end

=chapter SYNOPSIS

 # start using log4perl via a config file
 dispatcher Log::Log4perl => 'logger'
   , accept => 'NOTICE-'
   , config => "$ENV{HOME}/.log.conf";

 # disable default dispatcher
 dispatcher close => 'logger';

 # configuration inline, not in file: adapted from the Log4perl manpage
 my $name    = 'logger';
 my $outfile = '/tmp/a.log';
 my $config  = <<__CONFIG;
 log4perl.category.$name            = INFO, Logfile
 log4perl.appender.Logfile          = Log::Log4perl::Appender::File
 log4perl.appender.Logfile.filename = $outfn
 log4perl.appender.Logfile.layout   = Log::Log4perl::Layout::PatternLayout
 log4perl.appender.Logfile.layout.ConversionPattern = %d %F{1} %L> %m
 __CONFIG

 dispatcher 'Log::Log4perl' => $name, config => \$config;

=chapter DESCRIPTION
This dispatchers produces output tot syslog, based on the C<Sys::Log4perl>
module (which will not be automatically installed for you).

The REASONs for a message in M<Log::Report> are names quite similar to
the log-levels used by M<Log::Log4perl>.  The default mapping is list
below.  You can change the mapping using M<new(to_level)>.

  TRACE   => $DEBUG    ERROR   => $ERROR
  ASSERT  => $DEBUG    FAULT   => $ERROR
  INFO    => $INFO     ALERT   => $FATAL
  NOTICE  => $INFO     FAILURE => $FATAL
  WARNING => $WARN     PANIC   => $FATAL
  MISTAKE => $WARN

=chapter METHODS

=section Constructors

=c_method new TYPE, NAME, OPTIONS
The M<Log::Log4perl> infrastructure has all settings in a configuration
file.  In that file, you should find a category with the NAME.

=option  to_level ARRAY-of-PAIRS
=default to_level []
See M<reasonToLevel()>.

=requires config FILENAME|SCALAR
When a SCALAR reference is passed in, that must refer to a string which
contains the configuration text.  Otherwise, specify an existing FILENAME.
=cut

sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args);

    my $name   = $self->name;
    my $config = delete $args->{config}
       or error __x"Log::Log4perl back-end {name} requires a 'config' parameter"
            , name => $name;

    $self->{level}  = { %default_reasonToLevel };
    if(my $to_level = delete $args->{to_level})
    {   my @to = @$to_level;
        while(@to)
        {   my ($reasons, $level) = splice @to, 0, 2;
            my @reasons = expand_reasons $reasons;

            $level =~ m/^[0-5]$/
                or error __x "Log::Log4perl level '{level}' must be in 0-5"
                     , level => $level;

            $self->{level}{$_} = $level for @reasons;
        }
    }

    Log::Log4perl->init($config);

    $self->{appender} = Log::Log4perl->get_logger($name, %$args)
        or error __x"cannot find logger '{name}' in configuration {config}"
             , name => $name, config => $config;

    $self;
}

sub close()
{   my $self = shift;
    $self->SUPER::close or return;
    delete $self->{backend};
    $self;
}

=section Accessors

=method appender
Returns the M<Log::Log4perl::Logger> object which is used for logging.
=cut

sub appender() {shift->{appender}}

=section Logging
=cut

sub log($$$$)
{   my $self  = shift;
    my $text  = $self->SUPER::translate(@_) or return;
    my $level = $self->reasonToLevel($_[1]);

    local $Log::Log4perl::caller_depth
        = $Log::Log4perl::caller_depth + 3;

    $self->appender->log($level, $text);
    $self;
}

=method reasonToLevel REASON
Returns a level which is understood by Log::Dispatch, based on
a translation table.  This can be changed with M<new(to_level)>.

=example

 use Log::Log4perl     qw/:levels/;

 # by default, ALERTs are output as $FATAL
 dispatcher Log::Log4perl => 'logger'
   , to_level => [ ALERT => $ERROR, ]
   , ...;

=cut

sub reasonToLevel($) { $_[0]->{level}{$_[1]} }

1;
