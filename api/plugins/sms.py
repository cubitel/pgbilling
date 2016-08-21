
from plugin import Plugin
import urllib
import urllib2

class SMSPlugin(Plugin):
	Name = 'SMS Plugin'
	URL = ''
	
	def OnMainInit(self, db, config):
		db.cursor().execute("LISTEN sms;")
		return

	def OnWorkerInit(self, db, config):
		self.URL = config.get("sms", "url")
		return

	def OnCommand(self, cmd, data):
		if cmd == "pgNotify":
			if data['channel'] == "sms":
				params = data['payload'].split(',', 1)
				url = self.URL
				# Phone
				url = url.replace("{phone}", params[0])
				# Message
				msg = params[1].decode("utf-8").encode("utf_16_be")
				url = url.replace("{message}", urllib.quote_plus(msg))
				# do HTTP GET
				resp = urllib2.urlopen(url).read()

		return
