
use SOAP::WSDL;

package ws1c;

my $soap;

sub SOAP::Transport::HTTP::Client::get_basic_credentials {
	return 'billing' => '1234567890'
}

sub init {
	my ($self, $cfg, $dbh) = @_;

	$soap = SOAP::WSDL->new(
		wsdl => "http://www.webservicex.net/whois.asmx?WSDL"
	);

	$dbh->do("LISTEN payments_insert");
	$dbh->do("LISTEN tasks_insert");
}

sub event {
	my ($self, $event) = @_;
	
	if ($event eq 'payments_insert') {
		$soap->call('processPayments');
	}

	if ($event eq 'tasks_insert') {
		$soap->call('processTasks');
	}
}

1;
