
from plugin import Plugin
import psycopg2.extras
from subprocess import Popen, PIPE, STDOUT

class RadiusPlugin(Plugin):
	Name = 'RADIUS Plugin'

	def OnMainInit(self, db, config):
		db.cursor().execute("LISTEN radius_coa;")
		return

	def OnWorkerInit(self, db, config):
		self.db = db
		self.secret = config.get("radius", "secret")
		return

	def OnCommand(self, cmd, data):
		if cmd == "pgNotify":
			if data['channel'] == "radius_coa":
				cur = self.db.cursor(cursor_factory=psycopg2.extras.DictCursor)
				cur.execute("SELECT * FROM sessions WHERE session_id = %s;", (int(data['payload']), ))
				session = cur.fetchone()
				cur.execute("SELECT * FROM rad_attrs(%s);", (session['service_id'], ))
				indata = "User-Name = " + session['username']
				for attr in cur:
					indata += ', ' + attr['attribute'] + ' := "' + attr['value'] + '"'
				
				p = Popen(['radclient', '-x', session['nas_ip_address'] +':3799', 'coa', self.secret], stdout=PIPE, stdin=PIPE, stderr=STDOUT)
				res = p.communicate(input=indata)[0]

		return
