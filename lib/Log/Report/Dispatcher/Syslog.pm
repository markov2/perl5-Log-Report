use warnings;
use strict;

package Log::Report::Dispatcher::Syslog;
use base 'Log::Report::Dispatcher';

use Log::Report 'log-report';

use Sys::Syslog        qw/:standard :extended :macros/;
use Log::Report::Util  qw/@reasons expand_reasons/;
use Encode             qw/encode/;

use File::Basename qw/basename/;

my %default_reasonToPrio =
  ( TRACE   => LOG_DEBUG
  , ASSERT  => LOG_DEBUG
  , INFO    => LOG_INFO
  , NOTICE  => LOG_NOTICE
  , WARNING => LOG_WARNING
  , MISTAKE => LOG_WARNING
  , ERROR   => LOG_ERR
  , FAULT   => LOG_ERR
  , ALERT   => LOG_ALERT
  , FAILURE => LOG_EMERG
  , PANIC   => LOG_CRIT
  );

@reasons==keys %default_reasonToPrio
    or panic __"not all reasons have a default translation";

=chapter NAME
Log::Report::Dispatcher::Syslog - send messages to syslog

=chapter SYNOPSIS
 # add syslog dispatcher
 dispatcher SYSLOG => 'syslog', accept => 'NOTICE-'
   , format_reason => 'IGNORE'
   , to_prio => [ 'ALERT-' => 'err' ];

 # disable default dispatcher, when daemon
 dispatcher close => 'default';

=chapter DESCRIPTION
This dispatchers produces output to syslog, based on the M<Sys::Syslog>
module (which will NOT be automatically installed for you, because some
systems have a problem with this dependency).

The REASON for a message often uses names which are quite similar to
the log-levels used by syslog.  However: they have a different purpose.
The REASON is used by the programmer to indicate the cause of the message:
whether it was able to handle a certain situation.  The syslog levels
are there for the user's of the program (with syslog usually the
system administrators).  It is not unusual to see a "normal" error
or mistake as a very serious situation in a production environment. So,
you may wish to translate any message above reason MISTAKE into a LOG_CRIT.

The default translation table is list below.  You can change the mapping
using M<new(to_prio)>.  See example in SYNOPSIS.

  TRACE   => LOG_DEBUG    ERROR   => LOG_ERR
  ASSERT  => LOG_DEBUG    FAULT   => LOG_ERR
  INFO    => LOG_INFO     ALERT   => LOG_ALERT
  NOTICE  => LOG_NOTICE   FAILURE => LOG_EMERG
  WARNING => LOG_WARNING  PANIC   => LOG_CRIT
  MISTAKE => LOG_WARNING

=chapter METHODS

=section Constructors

=c_method new $type, $name, %options
With syslog, people tend not to include the REASON of the message
in the logs, because that is already used to determine the destination
of the message.

=default format_reason 'IGNORE'

=option  identity STRING
=default identity <basename $0>

=option  flags STRING
=default flags 'pid,nowait'
Any combination of flags as defined by M<Sys::Syslog>, for instance
C<pid>, C<ndelay>, and C<nowait>.

=option  facility STRING
=default facility 'user'
The possible values for this depend (a little) on the system.  POSIX
only defines C<user>, and C<local0> up to C<local7>.

=option  to_prio ARRAY-of-PAIRS
=default to_prio []
See M<reasonToPrio()>.

=option  logsocket 'unix'|'inet'|'stream'|HASH
=default logsocket C<undef>
If specified, the log socket type will be initialized to this before
C<openlog()> is called.  If not specified, the system default is used.

=option  include_domain BOOLEAN
=default include_domain <false>
[1.00] Include the text-domain of the message in each logged message.

=option  charset CHARSET
=default charset 'utf8'
Translate the text-strings into the specified charset, otherwise the
sysadmin may get unreadable text.

=option  format CODE
=default format <unchanged>
[1.10] With a CODE reference you get your hands on the text before
it gets sent to syslog.  The three parameters are: the (translated) text,
the related text domain object, and the message object.  You may want to
use context information from the latter.

[1.19] After the three positional parameters, there may be a list of
pairs (named parameters) with additional info.  This may contain a
C<location> with an ARRAY of information produced by caller() about the
origin of the exception.
=cut

my $active;

sub init($)
{   my ($self, $args) = @_;
    $args->{format_reason} ||= 'IGNORE';

    $self->SUPER::init($args);

    error __x"max one active syslog dispatcher, attempt for {new} have {old}"
      , new => $self->name, old => $active
        if $active;
    $active   = $self->name;

    setlogsock(delete $args->{logsocket})
        if $args->{logsocket};

    my $ident = delete $args->{identity} || basename $0;
    my $flags = delete $args->{flags}    || 'pid,nowait';
    my $fac   = delete $args->{facility} || 'user';
    openlog $ident, $flags, $fac;   # doesn't produce error.

    $self->{LRDS_incl_dom} = delete $args->{include_domain};
    $self->{LRDS_charset}  = delete $args->{charset} || "utf-8";
    $self->{LRDS_format}   = $args->{format} || sub {$_[0]};

    $self->{prio} = +{ %default_reasonToPrio };
    if(my $to_prio = delete $args->{to_prio})
    {   my @to = @$to_prio;
        while(@to)
        {   my ($reasons, $level) = splice @to, 0, 2;
            my @reasons = expand_reasons $reasons;

            my $prio    = Sys::Syslog::xlate($level);
            error __x"syslog level '{level}' not understood", level => $level
                if $prio eq -1;

            $self->{prio}{$_} = $prio for @reasons;
        }
    }

    $self;
}

sub close()
{   my $self = shift;
    undef $active;
    closelog;

    $self->SUPER::close;
}

#--------------
=section Accessors

=method format [CODE]
Returns the CODE ref which formats the syslog line.
=cut

sub format(;$)
{   my $self = shift;
    @_ ? $self->{LRDS_format} = shift : $self->{LRDS_format};
}

#--------------
=section Logging
=cut

sub log($$$$$)
{   my ($self, $opts, $reason, $msg, $domain) = @_;
    my $text   = $self->translate($opts, $reason, $msg) or return;
    my $format = $self->format;

    # handle each line in message separately
    $text    =~ s/\s+$//s;
    my @text = split /\n/, $format->($text, $domain, $msg, %$opts);

    my $prio    = $self->reasonToPrio($reason);
    my $charset = $self->{LRDS_charset};

    if($self->{LRDS_incl_dom} && $domain)
    {   $domain  =~ s/\%//g;    # security
        syslog $prio, "$domain %s", encode($charset, shift @text);
    }

    syslog $prio, "%s", encode($charset, $_)
        for @text;
}

=method reasonToPrio $reason
Returns a level which is understood by syslog(3), based on a translation
table.  This can be changed with M<new(to_prio)>.
=cut

sub reasonToPrio($) { $_[0]->{prio}{$_[1]} }

1;
