#!/usr/bin/perl

use Net::XMPP qw( Client );
$Con = new Net::XMPP::Client();

if (@ARGV != 2) {
	die "Usage: $0 <jabber-address> <password>\n";
}

my $CID = shift;
my $password = shift;

local $KB = $ENV{'USER'}."foaf";
local $OPT = "-f json";

$Con->AddNamespace(
	ns =>"http://www.w3.org/2005/09/xmpp-sparql-binding",
	tag =>"sparql",
	xpath => { Query => { path => "query/text()" },
	           Result => { path => "result/text()" } }
);

$Con->SetCallBacks(
	#send=>\&sendCallBack,
	#receive=>\&receiveCallBack,
	message=>\&messageCallBack,
	iq=>\&handleTheIQTag
);

my($user, $host) = $CID =~ /(.*)@(.*)/;
$status = $Con->Connect(hostname => $host);
my @ret = $Con->AuthSend(
	username => $user,
	password => $password,
	resource => 'sparql'
);

system("dns-sd -R $CID _sparqlxmpp._tcp local 5222 address=$CID &");

if ($ret[0] ne "ok") {
	die "Failed to authenticate to server: $ret[1]";
}

# higher level callbacks
#$Con->SetXPathCallBacks(
#	"/message[\@type='chat']"=>\&otherMessageChatCB,
#);

#my $Pres = new Net::XMPP::Presence();
$Con->RosterGet();
$Con->PresenceSend();

#$Pres->SetPresence(from=>"$CID", type=>"available", status=>"online");
#$ret = $Con->Send($Pres);

$ret = $Con->MessageSend(
	to => "theno23\@jabber.org",
	subject => "server up",
	body => "SPARQL server ".`uname -a`." awake",
	thread => "inform",
	priority => 10
);

my $quit = 0;

while (!$quit) {
	$status = $Con->Process(1);
	if (!defined $status) {
		$error = $Con->GetErrorCode();
		die "Fatal error: $error";
	}
}

$Con->Disconnect();

sub otherMessageChatCB {
	my($i, $m) = @_;

	my $msg = $m->GetBody();

	print("Chat body: ".$msg."\n");
	if ($msg =~ /QUIT/) {
		$quit = 1;
	} elsif ($msg =~ /(SELECT|CONSTRUCT)/) {
		my $to = $m->GetFrom();
		my $from = $m->GetTo();
		my $id = $m->GetID();
		my $query = $msg;

		sendtextres($from, $to, $id, $query);
	}
}

sub messageChatCB {
	my($i, $m) = @_;

	print("Body: ".$m->GetBody()."\n");
}

sub sendCallBack {
	my ($id, $msg) = @_;

	print "send: $msg\n";
}

sub receiveCallBack  {
	my ($id, $msg) = @_;

	print "RECV $id: ".$msg."\n";
}

sub messageCallBack  {
	print "mesg: ".join(",", @_)."\n";
}

sub handleTheIQTag  {
	my($id, $iq) = @_;

	my $namespace = $iq->GetQueryXMLNS();
	if ($namespace eq 'http://www.w3.org/2005/09/xmpp-sparql-binding') {
		my $from = $iq->GetFrom();
		my $query = $iq->GetQuery()->GetQuery();
		print("GOT SPARQL IQ $id $query from $from\n");
		if (!$query) {
			return;
		}
		&sendres($iq, $to, $from, $id, $query);
	} else {
		print("GOT $namespace $IQ from $from\n");
	}
}

sub sendtextres {
	my($from, $to, $id, $query) = @_;

	my $qres = `4s-query $OPT '$KB' '$query'`;
	$qres =~ s/&/\&amp;/g;
	$qres =~ s/</\&lt;/g;
	$qres =~ s/>/\&gt;/g;
$res = <<EOB;
<message from='$from' id='$id' to='$to'>
<body>
$qres
</body>
</message>
EOB
	$Con->Send($res);
}

sub sendres {
	my($qIQ, $from, $to, $id, $query) = @_;

	my $qres = `4s-query $OPT '$KB' '$query'`;
        my $IQ = $qIQ->Reply(type=>"result");
	$IQ->RemoveChild();
        my $IQSparql = $IQ->NewChild('http://www.w3.org/2005/09/xmpp-sparql-binding');
        $IQSparql->SetResult($qres);

	$Con->Send($IQ);
}

sub debugargs {
	print("DEBUG: ".join(" ", @_)."\n");
}
