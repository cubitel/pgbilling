
import os
import sys

Plugins = []

class Plugin(object):
	Name = 'undefined'
	
	def OnMainInit(self, db, config):
		pass
	
	def OnWorkerInit(self, db, config):
		pass
	
	def OnCommand(self, cmd, args):
		pass

def LoadPlugins():
	ss = os.listdir('plugins')
	sys.path.insert( 0, 'plugins')
	
	for s in ss:
		__import__(os.path.splitext(s)[ 0], None, None, [''])
	
	for plugin in Plugin.__subclasses__():
		p = plugin()
		Plugins.append(p)
	
	return
