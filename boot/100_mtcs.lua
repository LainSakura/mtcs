local fs = require('filesystem')
fs.mount('9b2', '/mtcs')
fs.link("/mtcs/lib", "/home/lib")
