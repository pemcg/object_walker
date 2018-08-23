# Change Log

## 2.0 (22-Aug-2018)
Re-factored to be callable as an embedded method in CFME 5.9/ManageIQ Gaprindashvili. Configuration parameters
are now in a new instance called 'configuration'

## 1.10 (21-Oct-2017)
More intelligent handing of broken associations. Includes a corresponding update to object_walker_reader.rb

## 1.9.3 (25-Jan-2017)
Bugfix - attributes containing arrays of service models weren't displayed

## 1.9.2 (22-Nov-2016)
Changed default value of $print\_evm\_parent to false

## 1.9.1 (08-Nov-2016)
Bugfix to work with ManageIQ Euwe/CFME 5.7

## 1.9 (14-Oct-2016)
Various bugfixes. Only call print\_tags if ServiceModelBase supports the taggable? method (CFME 5.6.2/Darga-4 and later).
Changed instance variables to be global variables (what was I thinking originally?)

## 1.8 (21-Jul-2016)
Added support for reading variables from the model, and took the black/whitelists out of the in-line code. Added print\_tags and print\_custom\_attributes.

## 1.7-1 (25-Apr-2016)
Added more of the base methods to the methods listing of objects

## 1.7 (08-Dec-2015)
Re-work indentation. We now indicate indentation level as a numeric value, and let the reader insert the actual indent space string.
Also add some of the new CFME 5.5 format objects to the whitelist

## 1.6-2 (30-Oct-2015)
Re-wrote walk\_object\_hierarchy to include walk\_object\_hierarchy. Now walks (correctly) the entire structure.

## 1.6-1 (19-Oct-2015)
Reformatted the walk\_association white/blacklists for appearance

## 1.6 (06-Oct-2015)
Refactored several internal methods. Add unique ID to dump output to allow interleaved dumps to be detected.
Added object hierarchy dump.
Changed output format slightly.
Allow for an override of @walk\_association\_whitelist to be input via a dialog element named 'dialog\_walk\_association\_whitelist'

## 1.5-3 (12-Jul-2015)
Refactored print\_attributes slightly to allow for the fact that options hash keys can be strings or symbols (a mix of the two causes sort to error)

## 1.5-2 (16-Apr-2015)
Dump $evm.object rather than $evm.current - they are the same but more code examples use
$evm.object so it's less ambiguous and possibly more useful to dump this

## 1.5-1 (16-Apr-2015)
Fixed a bug where sometimes the return from calling object.attributes isn't iterable

## 1.5 (15-Apr-2015)
Correctly format attributes that are actually hash keys (object['attribute'] rather than
object.attribute). This includes most of the attributes of $evm.root which had previously
been displayed incorrectly

## 1.4-7 (14-Apr-2015)
Don't try to dump $evm.parent if it's a NilClass (e.g. if vmdb\_object\_type = automation\_task)

## 1.4-6 (14-Apr-2015)
Dump $evm.current.attributes if there are any (arguments passed from a $evm.instantiate call)
e.g. $evm.instantiate("Discovery/Methods/ObjectWalker?provider=#{provider}&lunch=sandwich")

## 1.4-5 (29-Mar-2015)
Only dump the associations, methods and virtual columns of an MiqAeMethodService::* class

## 1.4-4 (08-Mar-2015)
Walk $evm.parent after $evm.root

## 1.4-3 (02-Mar-2015)
Detect duplicate entries in the associations list for each object

## 1.4-2 (27-Feb-2015)
Dump some $evm attributes first, and print the URI for an object type of DRb::DRbObject

## 1.4-1 (19-Feb-2015)
Changed singular/plural detection code in walk\_association to use active\_support/core\_ext/string

## 1.4 (15-Feb-2015)
Added print\_methods, renamed to object\_walker

## 1.3 (25-Sep-2014)
Debugged exception handling, changed some output strings

## 1.2 (24-Sep-2014)
Changed exception handling logic slightly

## 1.1 (22-Sep-2014)
Added blacklisting/whitelisting to the walk\_association functionality

## 1.0 (18-Sep-2014)
First release