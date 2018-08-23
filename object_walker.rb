module Investigative_Debugging
  module Discovery
    class ObjectWalker
      #
      # Can be called from anywhere in the CloudForms/ManageIQ automation namespace, and will walk the automation object structure starting from $evm.root
      # and dump (to automation.log) its attributes, any objects found, their attributes, virtual columns, and associations, and so on.
      #
      # Author:   Peter McGowan (pemcg@redhat.com)
      #           Copyright 2018 Peter McGowan, Red Hat
      #
      require 'active_support/core_ext/string'
      require 'securerandom'
      require 'json'
      
      VERSION             = "2.0"
      MAX_RECURSION_LEVEL = 7
      $debug              = false
      $print_methods      = true
      
      def self.walk_objects
        begin
          $recursion_level                      = 0
          $object_recorder                      = {}
          $service_model_base_supports_taggable = false
          #
          # Read our configuration instance to get the variables
          #
          instance = $evm.instantiate('/Discovery/ObjectWalker/configuration')
          if instance.nil?
            $evm.log(:error, "*** Instance /Discovery/ObjectWalker/configuration not found in Datastore ***")
            exit MIQ_ERROR
          end
          #
          # We need to record the instance methods of the MiqAeMethodService::MiqAeServiceModelBase class so that we can
          # subtract this list from the methods we discover for each object
          #
          $service_mode_base_instance_methods = []
          #
          # Change $max_recursion_level to adjust the depth of recursion that object_walker traverses through the objects
          #
          $max_recursion_level = instance['max_recursion_level'] || MAX_RECURSION_LEVEL
          #
          # $print_evm_object can be used to toggle whether or not to walk the object structure of the $evm.object (i.e current) object
          # If object_walker has been $evm.instantiated or invoked from a relationship then $evm.object will be object_walker itself. If
          # object_walker has been invoked from an embedded method then $evm.object is the calling method's instance.
          #
          $print_evm_object = instance['print_evm_object'].nil? ? false : instance['print_evm_object']
          unless [FalseClass, TrueClass].include? $print_evm_object.class
            $evm.log(:error, "*** print_evm_object must be a boolean value ***")
            exit MIQ_ERROR
          end
          #
          # $print_evm_parent can be used to toggle whether or not to walk the object structure of the $evm.parent object
          # If object_walker has been $evm.instantiated or invoked from a relationship then $evm.parent will be the calling
          # instance
          #
          $print_evm_parent = instance['print_evm_parent'].nil? ? false : instance['print_evm_parent']
          unless [FalseClass, TrueClass].include? $print_evm_parent.class
            $evm.log(:error, "*** print_evm_parent must be a boolean value ***")
            exit MIQ_ERROR
          end
          #
          # $print_nil_values can be used to toggle whether or not to include keys that have a nil value in the
          # output dump. There are often many, and including them will usually increase verbosity, but it is
          # sometimes useful to know that a key/attribute exists, even if it currently has no assigned value.
          #
          $print_nil_values = instance['print_nil_values'].nil? ? true : instance['print_nil_values']
          unless [FalseClass, TrueClass].include? $print_nil_values.class
            $evm.log(:error, "*** print_nil_values must be a boolean value ***")
            exit MIQ_ERROR
          end
          #
          # $walk_association_policy should have the value of either 'whitelist' or 'blacklist'. This will determine whether we either 
          # walk all associations _except_ those in the walk_association_blacklist hash, or _only_ the associations in the
          # walk_association_whitelist hash
          #
          $walk_association_policy = instance['walk_association_policy'] || 'whitelist'
          #
          # if $walk_association_policy = 'whitelist', then object_walker will only traverse associations of objects that are explicitly
          # mentioned in the $walk_association_whitelist hash. This enables us to carefully control what is dumped. If object_walker finds
          # an association that isn't in the hash, it will print a line similar to:
          #
          # $evm.root['user'].current_tenant (type: Association)
          # *** not walking: 'current_tenant' isn't in the walk_association_whitelist hash for MiqAeServiceUser ***
          #
          # If you wish to explore and dump this association, edit the hash to add the association name to the list associated with the object type. The string
          # 'ALL' can be used to walk all associations of an object type
          #
          dialog_walk_association_whitelist = ($evm.root['dialog_walk_association_whitelist'] != '') ? $evm.root['dialog_walk_association_whitelist'] : nil
          walk_association_whitelist = dialog_walk_association_whitelist || instance['walk_association_whitelist']
          #
          # if $walk_association_policy = 'blacklist', then object_walker will traverse all associations of all objects, except those
          # that are explicitly mentioned in the $walk_association_blacklist hash. This enables us to run a more exploratory dump, at the cost of a
          # much more verbose output. The string 'ALL' can be used to prevent walking any associations of an object type
          #
          # You have been warned, using a blacklist walk_association_policy produces a lot of output!
          #
          dialog_walk_association_blacklist = ($evm.root['dialog_walk_association_blacklist'] != '') ? $evm.root['dialog_walk_association_blacklist'] : nil
          walk_association_blacklist = dialog_walk_association_blacklist || instance['walk_association_blacklist'] 
          #
          # Generate a random string to identify this object_walker dump
          #
          randomstring = SecureRandom.hex(4).upcase
          $method = "object_walker##{randomstring}"
          
          $evm.log("info", "#{$method}:   Object Walker #{VERSION} Starting")
          print_line(0, "*** detected 'print_nil_values = false' so attributes with nil values will not be printed ***") if !$print_nil_values
          #
          # If we're dumping object methods, then we need to find out the methods of the
          # MiqAeMethodService::MiqAeServiceModelBase class so that we can subtract them from the method list
          # returned from each object. We know that MiqAeServiceModelBase is the superclass of
          # MiqAeMethodService::MiqAeServiceMiqServer, so we can get what we're after via $evm.root['miq_server']
          #
          miq_server = $evm.root['miq_server'] rescue nil
          unless miq_server.nil?
            if miq_server.method_missing(:class).superclass.name == "MiqAeMethodService::MiqAeServiceModelBase"
              $service_mode_base_instance_methods = miq_server.method_missing(:class).superclass.instance_methods.map { |x| x.to_s }
            else
              $evm.log("error", "#{$method} Unexpected parent class of $evm.root['miq_server']: " \
                                "#{miq_server.method_missing(:class).superclass.name}")
              $print_methods = false
            end
          else
            $evm.log("error", "#{$method} $evm.root['miq_server'] doesn't exist")
            $print_methods = false
          end
          $service_model_base_supports_taggable = true if $service_mode_base_instance_methods.include?('taggable?')
          
          print_line(0, "--- walk_association_policy details ---")
          print_line(0, "walk_association_policy = #{$walk_association_policy}")
          case $walk_association_policy
          when 'whitelist' 
            if walk_association_whitelist.nil?
              $evm.log(:error, "*** walk_association_whitelist not found, please define one as an instance attribute or a dialog variable ***")
              exit MIQ_ERROR
            else
              $walk_association_whitelist = JSON.parse(walk_association_whitelist.gsub(/\s/,'').gsub(/(?<!\\)'/, '"').gsub(/\\/,''))
              print_line(0, "walk_association_whitelist = #{walk_association_whitelist.gsub(/\s/,'')}")
            end
          when 'blacklist'
            if walk_association_blacklist.nil?
              $evm.log(:error, "*** walk_association_blacklist not found, please define one as an instance attribute or a dialog variable ***")
              exit MIQ_ERROR
            else
              $walk_association_blacklist = JSON.parse(walk_association_blacklist.gsub(/(?<!\\)'/, '"').gsub(/\\/,'').gsub(/\s/,''))
              print_line(0, "walk_association_blacklist = #{walk_association_blacklist.gsub(/\s/,'')}")
            end
          end
          #
          # Start with some $evm.current attributes
          #
          print_line(0, "--- $evm.current_* details ---")
          print_line(0, "$evm.current_namespace = #{$evm.current_namespace}   #{type($evm.current_namespace)}")
          print_line(0, "$evm.current_class = #{$evm.current_class}   #{type($evm.current_class)}")
          print_line(0, "$evm.current_instance = #{$evm.current_instance}   #{type($evm.current_instance)}")
          print_line(0, "$evm.current_method = #{$evm.current_method}   #{type($evm.current_method)}")
          print_line(0, "$evm.current_message = #{$evm.current_message}   #{type($evm.current_message)}")
          print_line(0, "$evm.current_object = #{$evm.current_object}   #{type($evm.current_object)}")
          print_line(0, "$evm.current_object.current_field_name = #{$evm.current_object.current_field_name}   " \
                       "#{type($evm.current_object.current_field_name)}")
          print_line(0, "$evm.current_object.current_field_type = #{$evm.current_object.current_field_type}   " \
                        "#{type($evm.current_object.current_field_type)}")
          #
          # See if RBAC is enabled
          #
          if $evm.respond_to?(:rbac_enabled?)
            if $evm.rbac_enabled?
              print_line(0, "--- RBAC within automation is enabled ---")
            else
              print_line(0, "--- RBAC within automation is disabled ---")
            end
          end
          #
          # and now print the object hierarchy...
          #
          print_line(0, "--- automation instance hierarchy ---")
          Struct.new('ServiceObject', :obj_name, :position, :children)
          # automation_object_hierarchy = Struct::ServiceObject.new(nil, nil, Array.new)
          automation_object_hierarchy = walk_automation_objects($evm.root)
          print_automation_objects(0, automation_object_hierarchy)
          #
          # Fire off a garbage collection to free up some space in the generic worker process
          #
          GC.start
          #
          # then walk and print $evm.root downwards...
          #
          print_line(0, "--- walking $evm.root ---")
          print_line(0, "$evm.root = #{$evm.root}   #{type($evm.root)}")
          walk_object("$evm.root", $evm.root)
          #
          # walk and print $evm.parent if requested...
          #
          unless $evm.parent.nil?
            if $print_evm_parent
              GC.start
              print_line(0, "--- walking $evm.parent ---")
              print_line(0, "$evm.parent = #{$evm.parent}   #{type($evm.parent)}")
              walk_object("$evm.parent", $evm.parent)
            end
          end
          #
          # and finally $evm.object if requested...
          #
          if $print_evm_object
            GC.start
            print_line(0, "--- walking $evm.object ---")
            print_line(0, "$evm.object = #{$evm.object}   #{type($evm.object)}")
            walk_object("$evm.object", $evm.object)
          end
          #
          # Exit method
          #
          $evm.log("info", "#{$method}:   Object Walker Complete")
          GC.start
        rescue JSON::ParserError  => err
          $evm.log("error", "#{$method} (object_walker) - Invalid JSON string passed as #{$walk_association_policy}")
          $evm.log("error", "#{$method} (object_walker) - Err: #{err.inspect}")
          exit MIQ_ERROR
        rescue => err
          $evm.log("error", "#{$method} (object_walker) - [#{err}]\n#{err.backtrace.join("\n")}")
          exit MIQ_ERROR
        end
      end

      private
            
      def self.walk_automation_objects(service_object)
        automation_object = Struct::ServiceObject.new(service_object.to_s, "", Array.new)
        if service_object.to_s == $evm.root.to_s
          automation_object.position = 'root'
        elsif service_object.to_s == $evm.parent.to_s
          automation_object.position = 'parent'
        elsif service_object.to_s == $evm.object.to_s
          automation_object.position = 'object'
        end
        offspring = service_object.children
        unless offspring.nil? || (offspring.kind_of?(Array) and offspring.length.zero?)
          Array.wrap(offspring).each do |child|
            automation_object.children << walk_automation_objects(child)
          end
        end
        return automation_object
      end
      
      def self.print_automation_objects(indent_level, hierarchy)
        case hierarchy.position
        when 'root'
          print_line(indent_level, "#{hierarchy.obj_name}  ($evm.root)")
        when 'parent'
          print_line(indent_level, "#{hierarchy.obj_name}  ($evm.parent)")
        when 'object'
          print_line(indent_level, "#{hierarchy.obj_name}  ($evm.object)")
        else
          print_line(indent_level, "#{hierarchy.obj_name}")
        end
        indent_level += 1
        hierarchy.children.each do |child|
          print_automation_objects(indent_level, child)
        end
      end
      
      def self.print_line(indent_level, string)
        $evm.log("info", "#{$method}:[#{indent_level.to_s}] #{string}")
      end
            
      def self.type(object)
        if object.is_a?(DRb::DRbObject)
          string = "(type: #{object.class}, URI: #{object.__drburi()})"
        else
          string = "(type: #{object.class})"
        end
        return string
      end
      
      def self.ping_attr(this_object, attribute)
        value = "<unreadable_value>"
        format_string = ".<unknown_attribute>"
        begin
          #
          # See if it's an attribute that we access using '.attribute'
          #
          value = this_object.method_missing(:send, attribute)
          format_string = ".#{attribute}"
        rescue NoMethodError
          #
          # Seems not, let's try to access as if it's a hash value
          #
          value = this_object[attribute]
          format_string = "['#{attribute}']"
        end
        return {:format_string => format_string, :value => value}
      end
      
      def self.str_or_sym(value)
        value_as_string = ""
        if value.is_a?(Symbol)
          value_as_string = ":#{value}"
        else
          value_as_string = "\'#{value}\'"
        end
        return value_as_string
      end
             
      def self.print_attributes(object_string, this_object)
        begin
          #
          # Print the attributes of this object
          #
          if this_object.respond_to?(:attributes)
            print_line($recursion_level, "Debug: this_object.inspected = #{this_object.inspect}") if $debug
            if this_object.attributes.respond_to?(:keys)
              if this_object.attributes.keys.length > 0
                print_line($recursion_level, "--- attributes follow ---")
                this_object.attributes.keys.sort.each do |attribute_name|
                  attribute_value = this_object.attributes[attribute_name]
                  if attribute_name != "options"
                    if attribute_value.is_a?(DRb::DRbObject)
                      if attribute_value.method_missing(:class).to_s =~ /^MiqAeMethodService.*/
                        print_line($recursion_level,
                                  "#{object_string}[\'#{attribute_name}\'] => #{attribute_value}   #{type(attribute_value)}")
                        walk_object("#{object_string}[\'#{attribute_name}\']", attribute_value)
                      elsif attribute_value.method_missing(:class).to_s == 'Array'
                        attr_info = ping_attr(this_object, attribute_name)
                        attribute_elements = []
                        attribute_value.each do |attribute_element|
                          attribute_elements << "#{attribute_element}"
                        end
                        print_line($recursion_level,
                                  "#{object_string}#{attr_info[:format_string]} = " \
                                  "#{attribute_elements}   (type: Array of Service Models)")
                      else
                        print_line($recursion_level,
                                  "*** unhandled attribute type: attribute_value.method_missing(:class) = " \
                                  "#{attribute_value.method_missing(:class)} ***") 
                      end
                    else
                      begin
                        attr_info = ping_attr(this_object, attribute_name)
                        if attr_info[:value].nil?
                          print_line($recursion_level,
                                    "#{object_string}#{attr_info[:format_string]} = nil") if $print_nil_values
                        else
                          print_line($recursion_level,
                                    "#{object_string}#{attr_info[:format_string]} = #{attr_info[:value]}   #{type(attr_info[:value])}")
                        end
                      rescue ArgumentError
                        if attribute_value.nil?
                          print_line($recursion_level,
                                    "#{object_string}.#{attribute_name} = nil") if $print_nil_values
                        else
                          print_line($recursion_level,
                                    "#{object_string}.#{attribute_name} = #{attribute_value}   #{type(attribute_value)}")
                        end
                      end
                    end
                  else
                    #
                    # Option key names can be mixed symbols and strings which confuses .sort
                    # Create an option_map hash that maps option_name.to_s => option_name
                    #
                    option_map = {}
                    options = attribute_value.keys
                    options.each do |option_name|
                      option_map[option_name.to_s] = option_name
                    end
                    option_map.keys.sort.each do |option|
                      if attribute_value[option_map[option]].nil?
                        print_line($recursion_level,
                                  "#{object_string}.options[#{str_or_sym(option_map[option])}] = nil") if $print_nil_values
                      else
                        print_line($recursion_level,
                                  "#{object_string}.options[#{str_or_sym(option_map[option])}] = " \
                                  "#{attribute_value[option_map[option]]}   #{type(attribute_value[option_map[option]])}")
                      end
                    end
                  end
                end
                print_line($recursion_level, "--- end of attributes ---")
              else  
                print_line($recursion_level, "--- no attributes ---")
              end
            else
              print_line($recursion_level, "*** attributes is not a hash ***")
            end
          else
            print_line($recursion_level, "--- no attributes ---")
          end
        rescue => err
          $evm.log("error", "#{$method} (print_attributes) - [#{err}]\n#{err.backtrace.join("\n")}")
        end
      end
      
      def self.print_virtual_columns(object_string, this_object, this_object_class)
        begin
          #
          # Only dump the virtual columns of an MiqAeMethodService::* class
          #
          if this_object.method_missing(:class).to_s =~ /^MiqAeMethodService.*/
            #
            # Print the virtual columns of this object 
            #
            virtual_column_names = []
            if this_object.respond_to?(:virtual_column_names)
              virtual_column_names = Array.wrap(this_object.virtual_column_names)
              if virtual_column_names.length.zero?
                print_line($recursion_level, "--- no virtual columns ---")
              else
                print_line($recursion_level, "--- virtual columns follow ---")
                virtual_column_names.sort.each do |virtual_column_name|
                  begin
                    virtual_column_value = this_object.method_missing(:send, virtual_column_name)
                    if virtual_column_value.nil?
                      print_line($recursion_level,
                                "#{object_string}.#{virtual_column_name} = nil") if $print_nil_values
                    else
                      print_line($recursion_level,
                                "#{object_string}.#{virtual_column_name} = " \
                                "#{virtual_column_value}   #{type(virtual_column_value)}")
                    end
                  rescue => err
                    print_line($recursion_level,
                              "!!! #{this_object_class} virtual column \'#{virtual_column_name}\' " \
                              "throws a #{err.class} exception when accessed (product bug?) !!!")
                  end
                end
                print_line($recursion_level, "--- end of virtual columns ---")
              end
            else
              print_line($recursion_level, "--- no virtual columns ---")
            end
          end
        rescue => err
          $evm.log("error", "#{$method} (print_virtual_columns) - [#{err}]\n#{err.backtrace.join("\n")}")
        end
      end
            
      def self.is_plural?(astring)
        astring.singularize != astring
      end
      
      def self.walk_association(object_string, association, associated_objects)
        begin
          #
          # Assemble some fake code to make it look like we're iterating though associations (plural)
          #
          number_of_associated_objects = associated_objects.length
          if is_plural?(association)
            assignment_string = "#{object_string}.#{association}.each do |#{association.singularize}|"
          else
            assignment_string = "#{association} = #{object_string}.#{association}"
          end
          print_line($recursion_level, "#{assignment_string}")
          associated_objects.each do |associated_object|
            associated_object_class = "#{associated_object.method_missing(:class)}".demodulize
            associated_object_id = associated_object.id rescue associated_object.object_id
            print_line($recursion_level, "(object type: #{associated_object_class}, object ID: #{associated_object_id})")
            if is_plural?(association)
              walk_object("#{association.singularize}", associated_object)
              if number_of_associated_objects > 1
                print_line($recursion_level,
                          "--- next #{association.singularize} ---")
                number_of_associated_objects -= 1
              else
                print_line($recursion_level,
                          "--- end of #{object_string}.#{association}.each do |#{association.singularize}| ---")
              end
            else
              walk_object("#{association}", associated_object)
            end
          end
        rescue => err
          $evm.log("error", "#{$method} (walk_association) - [#{err}]\n#{err.backtrace.join("\n")}")
        end
      end
      
      def self.print_associations(object_string, this_object, this_object_class)
        begin
          #
          # Only dump the associations of an MiqAeMethodService::* class
          #
          if this_object.method_missing(:class).to_s =~ /^MiqAeMethodService.*/
            #
            # Print the associations of this object according to the
            # $walk_associations_whitelist & $walk_associations_blacklist hashes
            #
            associations = []
            associated_objects = []
            duplicates = []
            if this_object.respond_to?(:associations)
              associations = Array.wrap(this_object.associations)
              if associations.length.zero?
                print_line($recursion_level, "--- no associations ---")
              else
                print_line($recursion_level, "--- associations follow ---")
                duplicates = associations.select{|item| associations.count(item) > 1}
                if duplicates.length > 0
                  print_line($recursion_level,
                            "*** De-duplicating the following associations: #{duplicates.inspect} ***")
                end
                associations.uniq.sort.each do |association|
                  begin
                    associated_objects = Array.wrap(this_object.method_missing(:send, association))
                    if associated_objects.length == 0
                      print_line($recursion_level,
                                "#{object_string}.#{association} (type: Association (empty))")
                    else
                      print_line($recursion_level, "#{object_string}.#{association} (type: Association)")
                      #
                      # See if we need to walk this association according to the walk_association_policy
                      # variable, and the walk_association_{whitelist,blacklist} hashes
                      #
                      if $walk_association_policy == 'whitelist'
                        if $walk_association_whitelist.has_key?(this_object_class) &&
                            ($walk_association_whitelist[this_object_class].include?('ALL') ||
                             $walk_association_whitelist[this_object_class].include?(association.to_s))
                          walk_association(object_string, association, associated_objects)
                        else
                          print_line($recursion_level,
                                    "*** not walking: \'#{association}\' isn't in the walk_association_whitelist " \
                                    "hash for #{this_object_class} ***")
                        end
                      elsif $walk_association_policy == 'blacklist'
                        if $walk_association_blacklist.has_key?(this_object_class) &&
                            ($walk_association_blacklist[this_object_class].include?('ALL') ||
                             $walk_association_blacklist[this_object_class].include?(association.to_s))
                          print_line($recursion_level,
                                    "*** not walking: \'#{association}\' is in the walk_association_blacklist " \
                                    "hash for #{this_object_class} ***")
                        else
                          walk_association(object_string, association, associated_objects)
                        end
                      else
                        print_line($recursion_level,
                                  "*** Invalid $walk_association_policy: #{$walk_association_policy} ***")
                        exit MIQ_ABORT
                      end
                    end
                  rescue => err
                    print_line($recursion_level,
                              "!!! #{this_object_class} association \'#{association}\' throws a " \
                              "#{err.class} exception when accessed (product bug?) !!!")
                    next
                  end
                end
                print_line($recursion_level, "--- end of associations ---")
              end
            else
              print_line($recursion_level, "--- no associations ---")
            end
          end
        rescue => err
          $evm.log("error", "#{$method} (print_associations) - [#{err}]\n#{err.backtrace.join("\n")}")
        end
      end
      
      def self.print_methods(object_string, this_object)
        begin
          #
          # Only dump the methods of an MiqAeMethodService::* class
          #
          if this_object.method_missing(:class).to_s =~ /^MiqAeMethodService.*/
            print_line($recursion_level,
                      "Class of remote DRb::DRbObject is: #{this_object.method_missing(:class)}") if $debug
            #
            # Get the instance methods of the class and convert to string
            #
            if this_object.method_missing(:class).respond_to?(:instance_methods)
              instance_methods = this_object.method_missing(:class).instance_methods.map { |x| x.to_s }
              #
              # Now we need to remove method names that we're not interested in...
              #
              # ...attribute names...
              #
              attributes = []
              if this_object.respond_to?(:attributes)
                if this_object.attributes.respond_to? :each
                  this_object.attributes.each do |key, value|
                    attributes << key
                  end
                end
              end
              attributes << "attributes"
              $evm.log("info", "Removing attributes: #{instance_methods & attributes}") if $debug
              instance_methods -= attributes
              #
              # ...association names...
              #
              associations = []
              if this_object.respond_to?(:associations)
                associations = Array.wrap(this_object.associations)
              end
              associations << "associations"
              $evm.log("info", "Removing associations: #{instance_methods & associations}") if $debug
              instance_methods -= associations
              #
              # ...virtual column names...
              #
              virtual_column_names = []
              virtual_column_names = this_object.method_missing(:virtual_column_names)
              virtual_column_names << "virtual_column_names"
              $evm.log("info", "Removing virtual_column_names: #{instance_methods & virtual_column_names}") if $debug
              instance_methods -= virtual_column_names
              #
              # ... MiqAeServiceModelBase methods ...
              #
              $evm.log("info", "Removing MiqAeServiceModelBase methods: " \
                               "#{instance_methods & $service_mode_base_instance_methods}") if $debug
              instance_methods -= $service_mode_base_instance_methods
              #
              # Add in the base methods as it's useful to show that they can be used with this object
              #
              instance_methods += ['inspect', 'inspect_all', 'reload', 'model_suffix']
              if this_object.respond_to?(:taggable?)
                if this_object.taggable?
                  instance_methods += ['tags', 'tag_assign', 'tag_unassign', 'tagged_with?']
                end
              else
                instance_methods += ['tags', 'tag_assign', 'tag_unassign', 'tagged_with?']
              end
              #
              # and finally dump out the list
              #
              if instance_methods.length.zero?
                print_line($recursion_level, "--- no methods ---")
              else
                print_line($recursion_level, "--- methods follow ---")
                instance_methods.sort.each do |instance_method|
                  print_line($recursion_level, "#{object_string}.#{instance_method}")
                end
                print_line($recursion_level, "--- end of methods ---")
              end
            else
              print_line($recursion_level, "--- no methods ---")
            end
          end
        rescue => err
          $evm.log("error", "#{$method} (print_methods) - [#{err}]\n#{err.backtrace.join("\n")}")
        end
      end
      
      def self.print_tags(this_object, this_object_class)
        begin
          if this_object.respond_to?(:taggable?)
            if this_object.taggable?
              tags = Array.wrap(this_object.tags)
              if tags.length.zero?
                print_line($recursion_level, "--- no tags ---")
              else
                print_line($recursion_level, "--- tags follow ---")
                tags.sort.each do |tag|
                  print_line($recursion_level, "#{tag}")
                end
                print_line($recursion_level, "--- end of tags ---")
              end
            else
              print_line($recursion_level, "--- object is not taggable ---")
            end
          else
            print_line($recursion_level, "--- no tags, or object is not taggable ---")
          end
          
        rescue NoMethodError
          print_line($recursion_level,
                    "*** #{this_object_class} gives a NoMethodError when the :tags method is accessed (product bug?) ***")
        rescue => err
          $evm.log("error", "#{$method} (print_tags) - [#{err}]\n#{err.backtrace.join("\n")}")
        end
      end
      
      def self.print_custom_attributes(object_string, this_object)
        begin
          if this_object.respond_to?(:custom_keys)
            custom_attribute_keys = Array.wrap(this_object.custom_keys)
            if custom_attribute_keys.length.zero?
              print_line($recursion_level, "--- no custom attributes ---")
            else
              print_line($recursion_level, "--- custom attributes follow ---")
              custom_attribute_keys.sort.each do |custom_attribute_key|
                custom_attribute_value = this_object.custom_get(custom_attribute_key)
                print_line($recursion_level, "#{object_string}.custom_get(\'#{custom_attribute_key}\') = \'#{custom_attribute_value}\'")
              end
              print_line($recursion_level, "--- end of custom attributes ---")
            end
          else
            print_line($recursion_level, "--- object does not support custom attributes ---")
          end    
        rescue => err
          $evm.log("error", "#{$method} (print_custom_attributes) - [#{err}]\n#{err.backtrace.join("\n")}")
        end
      end
      
      def self.walk_object(object_string, this_object)
        begin
          #
          # Make sure that we don't exceed our maximum recursion level
          #
          $recursion_level += 1
          if $recursion_level > $max_recursion_level
            print_line($recursion_level, "*** exceeded maximum recursion level ***")
            $recursion_level -= 1
            return
          end
          #
          # Make sure we haven't dumped this object already (some data structure links are cyclical)
          #
          this_object_id = this_object.id.to_s rescue this_object.object_id.to_s
          print_line($recursion_level,
                    "Debug: this_object.method_missing(:class) = #{this_object.method_missing(:class)}") if $debug
          this_object_class = "#{this_object.method_missing(:class)}".demodulize
          print_line($recursion_level, "Debug: this_object_class = #{this_object_class}") if $debug
          if $object_recorder.key?(this_object_class)
            if $object_recorder[this_object_class].include?(this_object_id)
              print_line($recursion_level,
                        "Object #{this_object_class} with ID #{this_object_id} has already been printed...")
              $recursion_level -= 1
              return
            else
              $object_recorder[this_object_class] << this_object_id
            end
          else
            $object_recorder[this_object_class] = []
            $object_recorder[this_object_class] << this_object_id
          end
          #
          # Dump out the things of interest
          #
          print_attributes(object_string, this_object)
          print_virtual_columns(object_string, this_object, this_object_class)
          print_associations(object_string, this_object, this_object_class)
          print_methods(object_string, this_object) if $print_methods
          print_tags(this_object, this_object_class) if $service_model_base_supports_taggable
          print_custom_attributes(object_string, this_object)
        
          $recursion_level -= 1
        rescue => err
          $evm.log("error", "#{$method} (walk_object) - [#{err}]\n#{err.backtrace.join("\n")}")
          $recursion_level -= 1
        end
      end
    end
  end
end
if $evm.object.name.match("ObjectWalker/object_walker")
  Investigative_Debugging::Discovery::ObjectWalker.walk_objects
end