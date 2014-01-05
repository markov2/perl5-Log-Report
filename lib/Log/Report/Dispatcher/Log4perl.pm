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
 # The name of the dispatcher is the name of the default category.
 dispatcher LOG4PERL => 'logger'
   , accept => 'NOTICE-'
   , config => "$ENV{HOME}/.log.conf";

 # disable default dispatcher
 dispatcher close => 'logger';

 # configuration inline, not in file: adapted from the Log4perl manpage
 my $name    = 'logger';
 my $outfile = '/tmp/a.log';
 my $config  = <<__CONFIG;
 log4perl.category.$name            = INFO, Logfile
 log4perl.logger.Logfile          = Log::Log4perl::Appender::File
 log4perl.logger.Logfile.filename = $outfn
 log4perl.logger.Logfile.layout   = Log::Log4perl::Layout::PatternLayout
 log4perl.logger.Logfile.layout.ConversionPattern = %d %F{1} %L> %m
 __CONFIG

 dispatcher LOG4PERL => $name, config => \$config;

=chapter DESCRIPTION
This dispatchers produces output tot syslog, based on the C<Sys::Log4perl>
module (which will not be automatically installed for you).

=section Reasons <--> Levels

The REASONs for a message in M<Log::Report> are names quite similar to
the log levels used by M<Log::Log4perl>.  The default mapping is list
below.  You can change the mapping using M<new(to_level)>.

  TRACE   => $DEBUG    ERROR   => $ERROR
  ASSERT  => $DEBUG    FAULT   => $ERROR
  INFO    => $INFO     ALERT   => $FATAL
  NOTICE  => $INFO     FAILURE => $FATAL
  WARNING => $WARN     PANIC   => $FATAL
  MISTAKE => $WARN

=section Categories

C<Log::Report> uses text-domains for translation tables.  These are
also used as categories for the Log4perl infrastructure.  So, typically
every module start with:

   use Log::Report 'my-text-domain', %more_options;

Now, if there is a logger inside the log4perl configuration which is
named 'my-text-domain', that will be used.  Otherwise, the name of the
dispatcher is used to select the logger.

=subsection Limitiations

The global C<$caller_depth> concept of M<Log::Log4perl> is broken.
That variable is used to find the filename and line number of the logged
messages.  But these messages may have been caught, rerouted, eval'ed, and
otherwise followed a unpredictable multi-leveled path before it reached
the Log::Log4perl dispatcher.  This means that layout patterns C<%F>
and C<%L> are not useful in the generic case, maybe in your specific case.

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

=default accept 'ALL'
=cut

sub init($)
{   my ($self, $args) = @_;
    $args->{accept} ||= 'ALL';
    $self->SUPER::init($args);

    my $name   = $self->name;
    my $config = delete $args->{config}
       or error __x"Log4perl back-end {name} requires a 'config' parameter"
            , name => $name;

    $self->{LRDL_levels}  = { %default_reasonToLevel };
    if(my $to_level = delete $args->{to_level})
    {   my @to = @$to_level;
        while(@to)
        {   my ($reasons, $level) = splice @to, 0, 2;
            my @reasons = expand_reasons $reasons;

            $level =~ m/^[0-5]$/
                or error __x "Log4perl level '{level}' must be in 0-5"
                     , level => $level;

            $self->{LRDL_levels}{$_} = $level for @reasons;
        }
    }

    Log::Log4perl->init($config)
        or return;

    $self;
}

#sub close()
#{   my $self = shift;
#    $self->SUPER::close or return;
#    $self;
#}

=section Accessors

=method logger [DOMAIN]
Returns the M<Log::Log4perl::Logger> object which is used for logging.
When there is no specific logger for this DOMAIN (logger with the exact
name of the DOMAIN) the default logger is being used, with the name of
this dispatcher.
=cut

sub logger(;$)
{   my ($self, $domain) = @_;
    defined $domain
        or return Log::Log4perl->get_logger($self->name);

    # get_logger() creates a logger if that does not exist.  But we
    # want to route it to default
    $Log::Log4perl::LOGGERS_BY_NAME->{$domain}
       ||= Log::Log4perl->get_logger($self->name);
}

=section Logging
=cut

sub log($$$$)
{   my ($self, $opts, $reason, $msg, $domain) = @_;
    my $text   = $self->translate($opts, $reason, $msg) or return;
    my $level  = $self->reasonToLevel($reason);

    local $Log::Log4perl::caller_depth = $Log::Log4perl::caller_depth + 3;

    $text =~ s/\s+$//s;  # log4perl adds own \n
    $self->logger($domain)->log($level, $text);
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

sub reasonToLevel($) { $_[0]->{LRDL_levels}{$_[1]} }

1;
