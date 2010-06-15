#!/usr/bin/perl

use Net::XMPP qw( Client );
$Con = new Net::XMPP::Client();

if (@ARGV != 3) {
	die "Usage: $0 <client-jabber-address> <password> <sparql-server-jabber-address>n";
}

my $CID = shift;
my $password = shift;
my $SID = shift;

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
	iq=>\&handleTheIQTag,
	error=>\&messageErrorCB
);

my($user, $host) = $CID =~ /(.*)@(.*)/;
if (!$user || !$host) {
	die "Failed to get user and host from CID";
}

my $status = $Con->Connect(hostname => $host);
if (!defined($status))
{
    print "Jabber server $host is down or connection was not allowed.\n";
    print "        ($!)\n";
    exit(1);
}

my @ret = $Con->AuthSend(
	username => $user,
	password => $password,
	resource => 'sparql'
);

if ($ret[0] ne "ok") {
	die "Failed to authenticate to $user @ $host, $ret[0]: $ret[1]";
}

$CID .= '/sparql';
$SID .= '/sparql';

while (my $cmd = <>) {
	my $ans = &sendquery($CID, $SID, $cmd);
	print("=== begin result ===\n".$ans."\n=== end result ===\n");
}

$Con->Disconnect();

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

	print $msg."\n";
}

sub messageCallBack  {
	print "mesg: ".join(",", @_)."\n";
}

sub sendquery {
	my($from, $to, $query) = @_;

	my $IQ = new Net::XMPP::IQ();
        $IQ->SetTo($to);
        $IQ->SetFrom($from);
        my $IQSparql = $IQ->NewChild('http://www.w3.org/2005/09/xmpp-sparql-binding');
	$IQSparql->SetQuery($query);

	my $answer = $Con->SendAndReceiveWithID($IQ);
	if (!$answer) {
		print("query response failed\n");

		return "";
	}

	return $answer->GetQuery()->GetResult();
}

sub handleTheIQTag  {
        my($id, $iq) = @_;

        my $namespace = $iq->GetQueryXMLNS();
        if ($namespace eq 'XXXhttp://www.w3.org/2005/09/xmpp-sparql-binding') {
                my $from = $iq->GetFrom();
                my $query = $iq->GetQuery()->GetQuery();
                print("GOT SPARQL IQ $id $query from $from\n");
                if (!$query) {
                        return;
                }
                &sendres($iq, $to, $from, $id, $query);
        } else {
                my $from = $iq->GetFrom();
                print("GOT $id $namespace $iq from $from\n");
        }
}

sub messageErrorCB {

    my ( $sid, $mess ) = @_;

    my $error     = $mess->GetError();
    my $errCode   = $mess->GetErrorCode();
    my $from      = $mess->GetFrom();
    my $to        = $mess->GetTo();
    my $timestamp = $mess->GetTimeStamp();

    if ( $errCode == 503 ) {
        print "503:$timestamp f:$from t:$to\n\n";
        return;
    }

    print "\nERR:$errCode:$error\n\n";
}

sub debugargs {
        print("DEBUG: ".join(" ", @_)."\n");
}

