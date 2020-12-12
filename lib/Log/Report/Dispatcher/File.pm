# This code is part of distribution Log-Report. Meta-POD processed with
# OODoc into POD and HTML manual-pages.  See README.md
# Copyright Mark Overmeer.  Licensed under the same terms as Perl itself.

package Log::Report::Dispatcher::File;
use base 'Log::Report::Dispatcher';

use warnings;
use strict;

use Log::Report  'log-report';
use IO::File     ();
use POSIX        qw/strftime/;

use Encode       qw/find_encoding/;
use Fcntl        qw/:flock/;

=chapter NAME
Log::Report::Dispatcher::File - send messages to a file or file-handle

=chapter SYNOPSIS
 dispatcher Log::Report::Dispatcher::File => 'stderr'
   , to => \*STDERR, accept => 'NOTICE-';

 # close a dispatcher
 dispatcher close => 'stderr';

 # let dispatcher open and close the file
 dispatcher FILE => 'mylog', to => '/var/log/mylog'
   , charset => 'utf-8';
 ...
 dispatcher close => 'mylog';  # will close file

 # open yourself, then also close yourself
 open OUT, ">:encoding('iso-8859-1')", '/var/log/mylog'
     or fault "...";
 dispatcher FILE => 'mylog', to => \*OUT;
 ...
 dispatcher close => 'mylog';  
 close OUT;

 # dispatch into a scalar
 my $output = '';
 open $outfile, '>', \$output;
 dispatcher FILE => 'into-scalar', to => \$outfile;
 ...
 dispatcher close => 'into-scalar';
 print $output;

=chapter DESCRIPTION
This basic file logger accepts an file-handle or filename as destination.

[1.00] writing to the file protected by a lock, so multiple processes
can write to the same file.

=chapter METHODS

=section Constructors

=c_method new $type, $name, %options

=requires to FILENAME|FILEHANDLE|OBJECT|CODE
You can either specify a FILENAME, which is opened in append mode with
autoflush on. Or pass any kind of FILE-HANDLE or some OBJECT which
implements a C<print()> method. You probably want to have autoflush
enabled on your FILE-HANDLES.

When cleaning-up the dispatcher, the file will only be closed in case
of a FILENAME.

[1.10] When you pass a CODE, then for each log message the function is
called with two arguments: this dispatcher object and the message object.
In some way (maybe via the message context) you have to determine the
log filename.  This means that probably many log-files are open at the
same time.

   # configuration time
   dispatcher FILE => 'logfile', to =>
       sub { my ($disp, $msg) = @_; $msg->context->{logfile} };

   # whenever you want to change the logfile
   textdomain->updateContext(logfile => '/var/log/app');
   (textdomain 'mydomain')->setContext(logfile => '/var/log/app');

   # or
   error __x"help", _context => {logfile => '/dev/tty'};
   error __x"help", _context => "logfile=/dev/tty";

=option  replace BOOLEAN
=default replace C<false>
Only used in combination with a FILENAME: throw away the old file
if it exists.  Probably you wish to append to existing information.

=default charset LOCALE
Use the LOCALE setting by default, which is LC_CTYPE or LC_ALL or LANG
(in that order).  If these contain a character-set which Perl understands,
then that is used, otherwise silently ignored.

=option  format CODE|'LONG'
=default format <adds timestamp>
[1.00] process each printed line.  By default, this adds a timestamp,
but you may want to add hostname, process number, or more.

   format => sub { '['.localtime().'] '.$_[0] }
   format => sub { shift }   # no timestamp
   format => 'LONG'

The first parameter to format is the string to print; it is already
translated and trailed by a newline.  The second parameter is the
text-domain (if known).

[1.10] As third parameter, you get the $msg raw object as well (maybe
you want to use the message context?)
[1.19] After the three positional parameters, there may be a list
of pairs providing additional facts about the exception.  It may
contain C<location> information.

The "LONG" format is equivalent to:

  my $t = strftime "%FT%T", gmtime;
  "[$t $$] $_[1] $_[0]"

Use of context:

   format => sub { my ($msgstr, $domain, $msg, %more) = @_;
      my $host = $msg->context->{host};
      "$host $msgstr";
   }

=cut

sub init($)
{   my ($self, $args) = @_;

    if(!$args->{charset})
    {   my $lc = $ENV{LC_CTYPE} || $ENV{LC_ALL} || $ENV{LANG} || '';
        my $cs = $lc =~ m/\.([\w-]+)/ ? $1 : '';
        $args->{charset} = length $cs && find_encoding $cs ? $cs : undef;
    }

    $self->SUPER::init($args);

    my $name = $self->name;
    $self->{to}      = $args->{to}
        or error __x"dispatcher {name} needs parameter 'to'", name => $name;
    $self->{replace} = $args->{replace} || 0;

    my $format = $args->{format} || sub { '['.localtime()."] $_[0]" };
    $self->{LRDF_format}
      = ref $format eq 'CODE' ? $format
      : $format eq 'LONG'
      ? sub { my $msg    = shift;
              my $domain = shift || '-';
              my $stamp  = strftime "%Y-%m-%dT%H:%M:%S", gmtime;
              "[$stamp $$] $domain $msg"
            }
      : error __x"unknown format parameter `{what}'"
          , what => ref $format || $format;

    $self;
}


=method close
Only when initiated with a FILENAME, the file will be closed.  In any
other case, nothing will be done.
=cut

sub close()
{   my $self = shift;
    $self->SUPER::close
        or return;

    my $to = $self->{to};
    my @close
      = ref $to eq 'CODE' ? values %{$self->{LRDF_out}}
      : $self->{LRDF_filename} ? $self->{LRDF_output}
      : ();

    $_ && $_->close for @close;
    $self;
}

#-----------
=section Accessors

=method filename
Returns the name of the opened file, or C<undef> in case this dispatcher
was started from a file-handle or file-object.

=method format
=cut

sub filename() {shift->{LRDF_filename}}
sub format()   {shift->{LRDF_format}}

=method output $msg
Returns the file-handle to write the log lines to. [1.10] This may
depend on the $msg (especially message context)
=cut

sub output($)
{   # fast simple case
    return $_[0]->{LRDF_output} if $_[0]->{LRDF_output};

    my ($self, $msg) = @_;
    my $name = $self->name;

    my $to   = $self->{to};
    if(!ref $to)
    {   # constant file name
        $self->{LRDF_filename} = $to;
        my $binmode = $self->{replace} ? '>' : '>>';

        my $f = $self->{LRDF_output} = IO::File->new($to, $binmode);
        unless($f)
        {   # avoid logging error to myself (issue #4)
            my $msg  = __x"cannot write log into {file} with mode '{binmode}'"
                 , binmode => $binmode, file => $to;
            if(my @disp = grep $_->name ne $name, Log::Report::dispatcher('list'))
            {   $msg->to($disp[0]->name);
                error $msg;
            }
            else
            {   die $msg;
            }
        }

        $f->autoflush;
        return $self->{LRDF_output} = $f;
    }

    if(ref $to eq 'CODE')
    {   # variable filename
        my $fn = $self->{LRDF_filename} = $to->($self, $msg);
        return $self->{LRDF_output} = $self->{LRDF_out}{$fn};
    }

    # probably file-handle
    $self->{LRDF_output} = $to;
}


#-----------
=section File maintenance

=method rotate $filename|CODE
[1.00] Move the current file to $filename, and start a new file.
=cut

sub rotate($)
{   my ($self, $old) = @_;

    my $to   = $self->{to};
    my $logs = ref $to eq 'CODE' ? $self->{LRDF_out}
      : +{ $self->{to} => $self->{LRDF_output} };
    
    while(my ($log, $fh) = each %$logs)
    {   !ref $log
           or error __x"cannot rotate log file which was opened as file-handle";


        my $oldfn = ref $old eq 'CODE' ? $old->($log) : $old;
        trace "rotating $log to $oldfn";

        rename $log, $oldfn
           or fault __x"unable to rotate logfile {fn} to {oldfn}"
               , fn => $log, oldfn => $oldfn;

        $fh->close;   # close after move not possible on Windows?
        my $f = $self->{LRDF_output} = $logs->{$log} = IO::File->new($log, '>>')
               or fault __x"cannot write log into {file}", file => $log;
        $f->autoflush;
    }

    $self;
}

#-----------
=section Logging
=cut

sub log($$$$)
{   my ($self, $opts, $reason, $msg, $domain) = @_;
    my $trans = $self->translate($opts, $reason, $msg);
    my $text  = $self->format->($trans, $domain, $msg, %$opts);

    my $out   = $self->output($msg);
    flock $out, LOCK_EX;
    $out->print($text);
    flock $out, LOCK_UN;
}

1;
