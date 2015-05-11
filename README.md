## object_walker

One of the challenges when starting out writing CloudForms or ManageIQ automation scripts, is knowing where the objects and attributes are under $evm.root that we may need to access. For example, depending on the automation action, we may have an $evm.root['vm'] object, or we may not.
 
This script is an attempt to demystify the object structure that is available at any point in the Automation engine. 

Calling the script from any point will walk the object hierarchy from $evm.root downwards, printing objects and attributes 
as it goes, i.e.


```
object_walker 1.5-2 - EVM Automate Method Started
     object_walker:   $evm.current_namespace = Bit63/Discovery   (type: String)
     object_walker:   $evm.current_class = ObjectWalker   (type: String)
     object_walker:   $evm.current_instance = default   (type: String)
     object_walker:   $evm.current_message = provisioning   (type: String)
     object_walker:   $evm.current_object = /Bit63/Discovery/ObjectWalker/default   (type: DRb::DRbObject, URI: druby://127.0.0.1:48366)
     object_walker:   $evm.current_object.current_field_name = provisioning   (type: String)
     object_walker:   $evm.current_object.current_field_type = method   (type: String)
     object_walker:   $evm.current_method = object_walk_provisioning   (type: String)
     object_walker:   $evm.root = /ManageIQ/System/Process/AUTOMATION   (type: DRb::DRbObject, URI: druby://127.0.0.1:48366)
     object_walker:   $evm.root['ae_provider_category'] = infrastructure   (type: String)
     object_walker:   $evm.root['ae_result'] = ok   (type: String)
     object_walker:   $evm.root['ae_state'] = ObjectWalker   (type: String)
     object_walker:   $evm.root['ae_state_retries'] = 0   (type: Fixnum)
     object_walker:   $evm.root['ae_state_started'] = 2015-05-11 14:51:50 UTC   (type: String)
     object_walker:   $evm.root['ae_status_state'] = on_entry   (type: String)
     object_walker:   $evm.root['miq_provision'] => #<MiqAeMethodService::MiqAeServiceMiqProvisionRedhat:0x00000009d76a78>   (type: DRb::DRbObject, URI: druby://127.0.0.1:48366)
     |    object_walker:   $evm.root['miq_provision'].created_on = 2015-05-11 14:41:49 UTC   (type: ActiveSupport::TimeWithZone)
     |    object_walker:   $evm.root['miq_provision'].description = Provision from [rhel7-generic] to [changeme]   (type: String)
     |    object_walker:   $evm.root['miq_provision'].destination_id = 1000000000090   (type: Fixnum)
     |    object_walker:   $evm.root['miq_provision'].destination_type = Vm   (type: String)
     ...
     |    object_walker:   $evm.root['miq_provision'].destination (type: Association)
     |    object_walker:   destination = $evm.root['miq_provision'].destination
     |    |    object_walker:   (object type: MiqAeServiceVmRedhat, object ID: 1000000000090)
     |    |    object_walker:   destination.autostart = nil
     |    |    object_walker:   destination.availability_zone_id = nil
     |    |    object_walker:   destination.blackbox_exists = nil
```
  etc
      
Many of the objects that we can walk through are in fact Rails Active Record Associations (object representations of database 
records), and we often don't want to print all of them. The script has a variable @walk_association_policy, that should have 
the value of either :whitelist or :blacklist. 

if @walk_association_policy = :whitelist, then object_walker will only traverse associations of objects that are explicitly
mentioned in the @walk_association_whitelist hash. This enables us to carefully control what is dumped. If object_walker finds
an association that isn't in the hash, it will print a line similar to:

$evm.root['vm'].datacenter (type: Association, objects found)
   (datacenter isn't in the @walk_associations hash for MiqAeServiceVmRedhat...)

If you wish to explore and dump this associaiton, edit the hash to add the association name to the list associated with the 
object type. The symbol :ALL can be used to walk all associations of an object type

```ruby
@walk_association_whitelist = { "MiqAeServiceServiceTemplateProvisionTask" => ["source", "destination", "miq_request"],
                                "MiqAeServiceServiceTemplate" => ["service_resources"],
                                "MiqAeServiceServiceResource" => ["resource", "service_template"],
                                "MiqAeServiceMiqProvisionRequest" => ["miq_request", "miq_request_tasks"],
                                "MiqAeServiceMiqProvisionRequestTemplate" => ["miq_request", "miq_request_tasks"],
                                "MiqAeServiceMiqProvisionVmware" => ["source", "destination", "miq_provision_request"],
                                "MiqAeServiceMiqProvisionRedhatViaPxe" => [:ALL],
                                "MiqAeServiceVmVmware" => ["ems_cluster", "storage", "service", "hardware"],
                                "MiqAeServiceVmRedhat" => ["ems_cluster", "storage", "service", "hardware"],
                                "MiqAeServiceHardware" => ["nics"]}
```

if @walk_association_policy = :blacklist, then object_walker will traverse all associations of all objects, except those that 
are explicitly mentioned in the @walk_association_blacklist hash. This enables us to run a more exploratory dump, at the 
cost of a much more verbose output. The symbol:ALL can be used to prevent the walking any associations of an object type

```ruby
@walk_association_blacklist = { "MiqAeServiceEmsCluster" => ["all_vms", "vms", "ems_events"],
                                "MiqAeServiceEmsRedhat" => ["ems_events"],
                                "MiqAeServiceHostRedhat" => ["guest_applications", "ems_events"]}
```


Several of the objects in the Automate model have circular references to themselves either directly or indirectly through 
other associations. To prevent the same object being dumped multiple times the script records where it's been, and prints:
 
```
object_walker:   Object MiqAeServiceServiceTemplate with ID 1000000000003 has already been dumped...
```

Many attributes that get dumped have a value of 'nil', i.e.
 
```      
object_walker:   $evm.root['user'] => #<MiqAeMethodService::MiqAeServiceUser:0x000000056e9bf0>   (type: DRb::DRbObject)  
      |    object_walker:   $evm.root['user'].created_on = 2014-09-16 07:52:05 UTC   (type: ActiveSupport::TimeWithZone)  
      |    object_walker:   $evm.root['user'].current_group_id = 1000000000001   (type: Fixnum)  
      |    object_walker:   $evm.root['user'].email = nil  
...  
      |    object_walker:   --- virtual columns follow ---  
      |    object_walker:   $evm.root['user'].allocated_memory = 0   (type: Fixnum)  
      |    object_walker:   $evm.root['user'].allocated_storage = 0   (type: Fixnum)  
      |    object_walker:   $evm.root['user'].allocated_vcpu = 0   (type: Fixnum)  
      |    object_walker:   $evm.root['user'].custom_1 = nil  
      |    object_walker:   $evm.root['user'].custom_2 = nil  
      |    object_walker:   $evm.root['user'].custom_3 = nil  
      |    object_walker:   $evm.root['user'].custom_4 = nil  
      |    object_walker:   $evm.root['user'].custom_5 = nil  
```
      
Sometimes we want to know that the attribute is present, even if its value is nil, but at other times we only wish to know
about attributes with valid values (this also gives us a more concise dump output). In this case we can define the script 
variable:
 
```ruby
@print_nil_values = false
```
 
and the resulting output dump will leave out any keys or attributes that have nil values.

### Installation

Under your own domain, create a new namespace, and a class to execute a single instance.

![Screenshot 1](/images/screenshot1.tiff)

Here I created an instance called ObjectWalker, and a method called object_walker containing the code.

### Calling object_walker

We get an object_walker dump by simply calling the new ObjectWalker instance from anywhere in the automation namespace, e.g.
from a state in the VM Provision State Machine:

![Screenshot 2](/images/screenshot2.tiff)

...or from a button on a VM:

![Screenshot 3](/images/screenshot3.tiff)

### Customising the output

The default @walk_association_whitelist dumps quite a lot of information, and it can be useful to tailor this for the particular
type of dump that we are interested in. We can modify our ObjectWalker class to call one of several object_walker methods, each with
a different @walk_association_whitelist, selected using a message when calling the instance.

![Screenshot 4](/images/screenshot6.tiff)

![Screenshot 5](/images/screenshot4.tiff)

Now we can call the appropriate copy of object_walker with our customised @walk_association_whitelist, for example to compare the
service provision data structure before and after calling CatalogItemInitialization:

![Screenshot 5](/images/screenshot5.tiff)

(we can use object_walker_reader --diff to compare the outputs - see below)

### object_walker_reader

Use object_walker_reader to extract the latest (no arguments), or a selected object_walker dump from automation.log or other 
renamed or saved log file.

```
Usage: object_walker_reader.rb [options]
    -l, --list                       list object_walker dumps in the file
    -f, --file filename              Full file path to automation.log (if not /var/www/miq/vmdb/log/automtion.log)
    -t, --timestamp timestamp        Date/time of the object_walker dump to be listed (hint: copy from -l output)
    -d, --diff timestamp1,timestamp2 Date/time of two object_walker dumps to be compared using 'diff'
    -h, --help                       Displays Help                    Displays Help

 #### Examples:
 
 ##### listing dumps

 ./object_walker_reader.rb -l
 Found object_walker dump at 2014-09-17T13:28:42.052043
 Found object_walker dump at 2014-09-17T13:34:52.649359
 Found object_walker dump at 2014-09-17T15:06:29.250086
 Found object_walker dump at 2014-09-17T15:22:46.034628
 Found object_walker dump at 2014-09-18T07:56:08.201025
 ...
 
 ##### listing dumps in a non-default (i.e. copied from another system) log file
 
 ./object_walker_reader.rb -l -f /Documents/CloudForms/cf30-automation-log
 Found object_walker dump at 2014-09-18T09:52:28.797868
 Found object_walker dump at 2014-09-18T09:53:31.455892
 Found object_walker dump at 2014-09-18T10:05:39.040744
 Found object_walker dump at 2014-09-18T12:00:59.142460
 ...
 
 ##### dumping a particular output by timestamp
 
 ./object_walker_reader.rb -t 2014-09-18T09:44:27.146812
 object_walker 1.0 - EVM Automate Method Started
      object_walker:   Dumping $evm.root
      object_walker:   $evm.root.ae_provider_category = infrastructure   (type: String)
      object_walker:   $evm.root.class = Methods   (type: String)
      object_walker:   $evm.root.instance = object_walker   (type: String)
      object_walker:   $evm.root['miq_server'] => # <MiqAeMethodService::MiqAeServiceMiqServer:0x00000008f242b8>   (type: DRb::DRbObject)
      |    object_walker:   $evm.root['miq_server'].build = 20140822170824_3268809   (type: String)
      |    object_walker:   $evm.root['miq_server'].capabilities = {:vixDisk=>true, :concurrent_miqproxies=>2}   (type: Hash)
      |    object_walker:   $evm.root['miq_server'].cpu_time = 2312.0   (type: Float)
      |    object_walker:   $evm.root['miq_server'].drb_uri = druby://127.0.0.1:50656   (type: String)
      |    object_walker:   $evm.root['miq_server'].guid = 5132a574-3d76-11e4-9150-001a4aa80204   (type: String)
      |    object_walker:   $evm.root['miq_server'].has_active_userinterface = true   (type: TrueClass)
      |    object_walker:   $evm.root['miq_server'].has_active_webservices = true   (type: TrueClass)
      |    object_walker:   $evm.root['miq_server'].hostname = cf31b2-1.bit63.net   (type: String)
      |    object_walker:   $evm.root['miq_server'].id = 1000000000001   (type: Fixnum)
      |    object_walker:   $evm.root['miq_server'].ipaddress = 192.168.2.77   (type: String)
      
 ##### Comparing the output from two dumps
      
 ./object_walker_reader.rb -d 2015-05-11T14:41:58.031661,2015-05-11T14:42:08.186930
 Getting diff comparison from dumps at 2015-05-11T14:41:58.031661 and 2015-05-11T14:42:08.186930
 6c6
 <      object_walker:   $evm.current_object = /Bit63/Discovery/ObjectWalker/default   (type: DRb::DRbObject, URI: druby://127.0.0.1:51860)
 ---
 >      object_walker:   $evm.current_object = /Bit63/Discovery/ObjectWalker/default   (type: DRb::DRbObject, URI: druby://127.0.0.1:54749)
 10c10
 <      object_walker:   $evm.root = /Bit63/Service/Provisioning/StateMachines/ServiceProvision_Template/CatalogItemInitialization   (type: DRb::DRbObject, URI: druby://127.0.0.1:51860)
 ---
 >      object_walker:   $evm.root = /Bit63/Service/Provisioning/StateMachines/ServiceProvision_Template/CatalogItemInitialization   (type: DRb::DRbObject, URI: druby://127.0.0.1:54749)
 12c12
 <      object_walker:   $evm.root['ae_state'] = pre1   (type: String)
 ---
 >      object_walker:   $evm.root['ae_state'] = pre3   (type: String)
 14c14
 <      object_walker:   $evm.root['ae_state_started'] = 2015-05-11 14:41:56 UTC   (type: String)
 ---
 >      object_walker:   $evm.root['ae_state_started'] = 2015-05-11 14:42:07 UTC   (type: String) 
  ... 
```
To use, simple copy the object_walker_reader.rb file to the CloudForms appliance, and run.