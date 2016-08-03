
from plugin import Plugin

from pysnmp.carrier.asynsock.dispatch import AsynsockDispatcher
from pysnmp.carrier.asynsock.dgram import udp, udp6
from pyasn1.codec.ber import decoder
from pysnmp.proto import api

def snmpTrapRecv(transportDispatcher, transportDomain, transportAddress, wholeMsg):
	while wholeMsg:
		msgVer = int(api.decodeMessageVersion(wholeMsg))
		if msgVer in api.protoModules:
			pMod = api.protoModules[msgVer]
		else:
			print('Unsupported SNMP version %s' % msgVer)
			return
		reqMsg, wholeMsg = decoder.decode(
			wholeMsg, asn1Spec=pMod.Message(),
			)
		print('Notification message from %s:%s: ' % (
			transportDomain, transportAddress
			)
		)
		reqPDU = pMod.apiMessage.getPDU(reqMsg)
		if reqPDU.isSameTypeWith(pMod.TrapPDU()):
			if msgVer == api.protoVersion1:
				print('Enterprise: %s' % (
					pMod.apiTrapPDU.getEnterprise(reqPDU).prettyPrint()
					)
				)
				print('Agent Address: %s' % (
					pMod.apiTrapPDU.getAgentAddr(reqPDU).prettyPrint()
					)
				)
				print('Generic Trap: %s' % (
					pMod.apiTrapPDU.getGenericTrap(reqPDU).prettyPrint()
					)
				)
				print('Specific Trap: %s' % (
					pMod.apiTrapPDU.getSpecificTrap(reqPDU).prettyPrint()
					)
				)
				print('Uptime: %s' % (
					pMod.apiTrapPDU.getTimeStamp(reqPDU).prettyPrint()
					)
				)
				varBinds = pMod.apiTrapPDU.getVarBindList(reqPDU)
			else:
				varBinds = pMod.apiPDU.getVarBindList(reqPDU)
			print('Var-binds:')
			for oid, val in varBinds:
				print('%s = %s' % (oid.prettyPrint(), val.prettyPrint()))
	return wholeMsg

class SnmpTrap(Plugin):

	def OnMainInit(self, db, config):
		transportDispatcher = AsynsockDispatcher()
		transportDispatcher.registerRecvCbFun(snmpTrapRecv)

		# UDP/IPv4
		transportDispatcher.registerTransport(
			udp.domainName, udp.UdpSocketTransport().openServerMode(('localhost', 162))
		)

#		transportDispatcher.jobStarted(1)

#		try:
#			# Dispatcher will never finish as job#1 never reaches zero
#			transportDispatcher.runDispatcher()
#		except:
#			transportDispatcher.closeDispatcher()
#			raise
