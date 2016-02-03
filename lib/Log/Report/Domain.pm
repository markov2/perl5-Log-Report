use warnings;
use strict;

package Log::Report::Domain;
use base 'Log::Report::Minimal::Domain';

use Log::Report        'log-report';
use Log::Report::Util  qw/parse_locale/;
use Scalar::Util       qw/blessed/;

use Log::Report::Translator;

=chapter NAME
Log::Report::Domain - administer one text-domain

=chapter SYNOPSIS

 # internal usage
 use Log::Report::Domain;
 my $domain = Log::Report::Domain->new(name => $name);

 # find a ::Domain object
 use Log::Report 'my-domain';
 my $domain = textdomain 'my-domain'; # find domain config
 my $domain = textdomain;             # config of this package

 # explicit domain configuration
 package My::Package;
 use Log::Report 'my-domain';         # set textdomain for package

 textdomain $name, %configure;        # set config, once per program
 (textdomain $name)->configure(%configure); # same
 textdomain->configure(%configure);   # same if current package in $name

 # implicit domain configuration
 package My::Package;
 use Log::Report 'my-domain', %configure;
 
 # external file for configuration (perl or json format)
 use Log::Report 'my-domain', config => $filename;

 use Log::Report 'my-domain';
 textdomain->configure(config => $filename);

=chapter DESCRIPTION 

L<Log::Report> can handle multiple sets of packages at the same
time: in the usual case a program consists of more than one software
distribution, each containing a number of packages.  Each module
in an application belongs to one of these sets, by default the domain set
'default'.

For C<Log::Report>, those packags sets are differentiated via the
text-domain value in the C<use> statement:

  use Log::Report 'my-domain';

There are many things you can configure per (text)domain.  This is not
only related to translations, but also -for instance- for text formatting
configuration.  The administration for the configuration is managed in
this package.

=chapter METHODS

=section Constructors

=c_method new %options
Create a new Domain object.
=cut

sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args);
    $self->{LRD_ctxt_def} = {};
    $self;
}

#----------------
=section Attributes
=method nativeLanguage
=method translator
=method contextRules
=cut

sub nativeLanguage() {shift->{LRD_native}}
sub translator()     {shift->{LRD_transl}}
sub contextRules()   {shift->{LRD_ctxt_rules}}

#----------------
=method configure %options
The import is automatically called when the package is compiled.  For all
but one packages in your distribution, it will only contain the name of
the DOMAIN.  For one package, it will contain configuration information.
These %options are used for all packages which use the same DOMAIN.
See chapter L</Configuring> below.

=option  formatter CODE|'PRINTI'|'PRINTP'
=default formatter C<PRINTI>
Selects the formatter used for the errors messages.  The default is C<PRINTI>,
which will use M<String::Print::printi()>: interpolation with curly
braces around the variable names.  C<PRINTP> uses positional parameters,
just like C<printf>, implemented by M<String::Print::printp()>.

=option  translator M<Log::Report::Translator>|HASH
=default translator C<created internally>
Set the object which will do the translations for this domain.

=option  native_language CODESET 
=default native_language 'en_US'
This is the language which you have used to write the translatable and
the non-translatable messages in.  In case no translation is needed,
you still wish the system error messages to be in the same language
as the report.  Of course, each textdomain can define its own.

=option  context_rules HASH|OBJECT
=default context_rules C<undef>
When rules are provided, the translator will use the C<msgctxt> fields
as provided by PO-files (gettext).  This parameter is used to initialize
a M<Log::Report::Translator::Context> helper object.

=option  config FILENAME
=default config C<undef>
Read the settings from the file.  The parameters found in the file are
used as default for the parameters above.  This parameter is especially
useful for the C<context_rules>, which need to be shared between the
running application and F<xgettext-perl>.  See M<readConfig()>

=cut

sub configure(%)
{   my ($self, %args) = @_;

    if(my $config = delete $args{config})
    {   my $set = $self->readConfig($config);
        %args   = (%$set, %args);
    }

    # 'formatter' is handled by the base-class, but documented here.
    $self->SUPER::configure(%args);

    my $transl = $args{translator} || Log::Report::Translator->new;
    $transl    =  Log::Report::Translator->new(%$transl)
        if ref $transl eq 'HASH';

    !blessed $transl || $transl->isa('Log::Report::Translator')
        or panic "translator must be a Log::Report::Translator object";
    $self->{LRD_transl} = $transl;

    my $native = $self->{LRD_native}
      = $args{native_language} || 'en_US';

    my ($lang) = parse_locale $native;
    defined $lang
        or error __x"the native_language '{locale}' is not a valid locale"
            , locale => $native;

    if(my $cr = $args{context_rules})
    {   my $tc = 'Log::Report::Translator::Context';
        eval "require $tc"; panic $@ if $@;
        if(blessed $cr)
        {   $cr->isa($tc) or panic "context_rules must be a $tc" }
        elsif(ref $cr eq 'HASH')
        {   $cr = Log::Report::Translator::Context->new(rules => $cr) }
        else
        {   panic "context_rules expects object or hash, not {have}", have=>$cr;
        }

        $self->{LRD_ctxt_rules} = $cr;
    }

    $self;
}

=method setContext STRING|HASH|ARRAY|PAIRS
Temporary set the default translation context for messages.  This is used
when the message is created without a C<_context> parameter. The context
can be retrieved with M<defaultContext()>.

Contexts are totally ignored then there are no C<context_rules>.  When
you do not wish to change settings, you may simply provide a HASH.

=example
   use Log::Report 'my-domain', context_rules => {};
=cut

sub setContext(@)
{   my $self = shift;
    my $cr   = $self->contextRules  # ignore context if no rules given
        or error __x"you need to configure context_rules before setContext";

    $self->{LRD_ctxt_def} = $cr->needDecode(set => @_);
}

=method updateContext STRING|HASH|ARRAY|PAIRS
[1.10] Make changes and additions to the active context (see M<setContext()>).
=cut

sub updateContext(@)
{   my $self = shift;
    my $cr   = $self->contextRules  # ignore context if no rules given
        or return;

    my $rules = $cr->needDecode(update => @_);
    my $r = $self->{LRD_ctxt_def} ||= {};
    @{$r}{keys %$r} = values %$r;
    $r;
}

=method defaultContext
Returns the current default translation context settings as HASH.  You should
not modify the content of that HASH: change it by called M<setContext()> or
M<updateContext()>.
=cut

sub defaultContext() { shift->{LRD_ctxt_def} }

=ci_method readConfig $filename
Helper method, which simply parses the content $filename into a HASH to be
used as parameters to M<configure()>. The filename must end on '.pl',
to indicate that it uses perl syntax (can be processed with Perl's C<do>
command) or end on '.json'.  See also chapter L</Configuring> below.

Currently, this file can be in Perl native format (when ending on C<.pl>)
or JSON (when it ends with C<.json>).  Various modules may explain parts
of what can be found in these files, for instance
M<Log::Report::Translator::Context>.
=cut

sub readConfig($)
{   my ($self, $fn) = @_;
    my $config;

    if($fn =~ m/\.pl$/i)
    {   $config = do $fn;
    }
    elsif($fn =~ m/\.json$/i)
    {   eval "require JSON"; panic $@ if $@;
        open my($fh), '<:encoding(utf8)', $fn
            or fault __x"cannot open JSON file for context at {fn}"
               , fn => $fn;
        local $/;
        $config = JSON->utf8->decode(<$fh>);
    }
    else
    {   error __x"unsupported context file type for {fn}", fn => $fn;
    }

    $config;
}

#-------------------
=section Action

=method translate $message, $language
Translate the $message into the $language.
=cut

sub translate($$)
{   my ($self, $msg, $lang) = @_;

    my ($msgid, $msgctxt);
    if(my $rules = $self->contextRules)
    {   ($msgid, $msgctxt)
           = $rules->ctxtFor($msg, $lang, $self->defaultContext);
    }
    else
    {   $msgid = $msg->msgid;
        1 while $msgid =~
            s/\{([^}]*)\<\w+([^}]*)\}/length "$1$2" ? "{$1$2}" : ''/e;
    }

    # This is ugly, horrible and worse... but I do not want to mutulate
    # the message neither to clone it.  We do need to get rit of {<}
    local $msg->{_msgid} = $msgid;

    my $tr = $self->translator || $self->configure->translator;
    $tr->translate($msg, $lang, $msgctxt) || $msgid;
}

1;

__END__
=chapter DETAILS

=section Configuring

Configuration of a domain can happen in many ways: either explicitly or
implicitly.  The explicit form:

   package My::Package;
   use Log::Report 'my-domain';

   textdomain 'my-domain', %configuration;
   textdomain->configure(%configuration);
   textdomain->configure(\%configuration);

   textdomain->configure(conf => $filename);

The implicit form is (no variables possible, only constants!)

   package My::Package;
   use Log::Report 'my-domain', %configuration;
   use Log::Report 'my-domain', conf => '/filename';

You can only configure your domain in one place in your program.  The
textdomain setup is then used for all packages in the same domain.

This also works for M<Log::Report::Optional>, which is a dressed-down
version of M<Log::Report>.

=subsection configuring your formatter

The C<PRINTI> and C<PRINTP> are special constants for M<configure(formatter)>,
and will use M<String::Print> functions C<printi()> respectively C<printp()>
in their default modus.  When you want your own formatter, or configuration
of C<String::Print>, you need to pass a code reference.

  my $sp = String::Print->new
    ( modifiers   => ...
    , serializers => ...
    );

  textdomain 'some-domain'
    , formatter => sub { $sp->printi(@_) };

=subsection configuring global values

Say, you log for a (Dancer) webserver, where you wish to include the website
name in some of the log lines.  For this, (ab)use the translation context:

  ### first enabled translation contexts
  use Log::Report 'my-domain', context_rules => {};
  # or
  use Log::Report 'my-domain';
  textdomain->configure(context_rules => {});
  
  ### every time you start working for a different virtual host
  (textdomain 'my-domain')->setContext(host => $host);

  ### now you can use that in your code
  package My::Package;
  use Log::Report 'my-domain';
  error __x"in {host} not logged-in {user}", user => $username;

=cut
