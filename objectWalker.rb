begin
  @version = 1.0
  @method = 'objectWalker'
  @recursion_level = 0
  MAX_RECURSION_LEVEL = 6
  @object_recorder = {}
  @print_nil_values = false
  @debug = false
  @walk_associations = { "MiqAeServiceServiceTemplateProvisionTask" => ["source", "destination", "miq_request", "miq_request_tasks", "service_resource"],
                          "MiqAeServiceServiceTemplate" => ["service_resources"],
                          "MiqAeServiceServiceResource" => ["resource", "service_template"],
                          "MiqAeServiceMiqProvisionRequest" => ["miq_request", "miq_request_tasks"],
                          "MiqAeServiceMiqProvisionRequestTemplate" => ["miq_request", "miq_request_tasks"],
                          "MiqAeServiceMiqProvisionVmware" => ["source", "destination", "miq_provision_request", "miq_request", "miq_request_task", "vm"],
                          "MiqAeServiceMiqProvisionRedhatViaPxe" => [:ALL],
                          "MiqAeServiceVmVmware" => ["ems_cluster", "ems_folder", "resource_pool", "ext_management_system", "storage", "service"],
                          "MiqAeServiceVmRedhat" => ["ems_cluster", "ems_folder", "resource_pool", "ext_management_system", "storage", "service", "hardware"],
                          "MiqAeServiceHardware" => ["nics"]}
  
  $evm.log("info", "#{@method} #{@version} - EVM Automate Method Started")
  
  def dump_attributes(object_string, this_object, spaces)
    #
    # Print the attributes of this object
    #
    if this_object.respond_to?(:attributes)
      $evm.log("info", "#{spaces}#{@method}:   Debug: this_object.inspected = #{this_object.inspect}") if @debug
      this_object.attributes.sort.each do |key, value|
        if key != "options"
          if value.is_a?(DRb::DRbObject)
            $evm.log("info", "#{spaces}#{@method}:   #{object_string}[\'#{key}\'] => #{value}   (type: #{value.class})")
            dump_object("#{object_string}[\'#{key}\']", value, spaces)
          else
            if value.nil?
              $evm.log("info", "#{spaces}#{@method}:   #{object_string}.#{key} = nil") if @print_nil_values
            else
              $evm.log("info", "#{spaces}#{@method}:   #{object_string}.#{key} = #{value}   (type: #{value.class})")
            end
          end
        else
          value.sort.each do |k,v|
            if v.nil?
              $evm.log("info", "#{spaces}#{@method}:   #{object_string}.options[:#{k}] = nil") if @print_nil_values
            else
              $evm.log("info", "#{spaces}#{@method}:   #{object_string}.options[:#{k}] = #{v}   (type: #{v.class})")
            end
          end
        end
      end
    else
      $evm.log("info", "#{spaces}#{@method}:   This object has no attributes")
    end
  end
  
  def dump_virtual_columns(object_string, this_object, spaces)
    #
    # Print the virtual columns of this object 
    #
    if this_object.respond_to?(:virtual_column_names)
      $evm.log("info", "#{spaces}#{@method}:   --- virtual columns follow ---")
      this_object.virtual_column_names.sort.each do |virtual_column_name|
        virtual_column_value = this_object.send(virtual_column_name)
        if virtual_column_value.nil?
          $evm.log("info", "#{spaces}#{@method}:   #{object_string}.#{virtual_column_name} = nil") if @print_nil_values
        else
          $evm.log("info", "#{spaces}#{@method}:   #{object_string}.#{virtual_column_name} = #{virtual_column_value}   (type: #{virtual_column_value.class})")
        end
      end
      $evm.log("info", "#{spaces}#{@method}:   --- end of virtual columns ---")
    end
  end
  
  def dump_associations(object_string, this_object, this_object_class, spaces)
    #
    # Print the associations of this object if defined in the @walk_associations hash
    #
    object_associations = []
    associated_objects = []
    if this_object.respond_to?(:associations)
      object_associations = Array(this_object.associations)
      object_associations.sort.each do |association|
        begin
          associated_objects = Array(this_object.send(association))
          if associated_objects.length == 0
            $evm.log("info", "#{spaces}#{@method}:   #{object_string}.#{association} (type: Association, no objects found)")
          else
            $evm.log("info", "#{spaces}#{@method}:   #{object_string}.#{association} (type: Association, objects found)")
            #
            # See if we need to walk this association 
            #
            walk_this = false
            if @walk_associations.has_key?(this_object_class)
              if @walk_associations[this_object_class].include?(:ALL) || @walk_associations[this_object_class].include?(association.to_s)
                walk_this = true
                if (association =~ /.*s$/)
                  assignment_string = "#{object_string}.#{association}.each do |#{association.chop}|"
                else
                  assignment_string = "#{association} = #{object_string}.#{association}"
                end
                $evm.log("info", "#{spaces}#{@method}:   #{assignment_string}")
                associated_objects.each do |associated_object|
                  associated_object_class = "#{associated_object.method_missing(:class)}".demodulize
                  associated_object_id = associated_object.id rescue associated_object.object_id
                  $evm.log("info", "#{spaces}|    #{@method}:   (object type: #{associated_object_class}, object ID: #{associated_object_id})")
                  if (association =~ /.*s$/)
                    dump_object("#{association.chop}", associated_object, spaces)
                    $evm.log("info", "#{spaces}#{@method}:  ---")
                  else
                    dump_object("#{association}", associated_object, spaces)
                  end
                end
              end
            end
            unless walk_this
              $evm.log("info", "#{spaces}#{@method}:     (#{association} isn't in the @walk_associations hash for #{this_object_class}...)")
            end
          end
        rescue NoMethodError
          $evm.log("info", "#{spaces}#{@method}:     #{this_object_class} claims to have an association of \'#{association}\', but this gives a NoMethodError when accessed")
        end
      end
    else
      $evm.log("info", "#{spaces}#{@method}:   This object has no associations")
    end
  end
  
  def dump_object(object_string, this_object, spaces)
    if @recursion_level == 0
      spaces += "     "
    else
      spaces += "|    "
    end
    #
    # Make sure that we don't exceed our maximum recursion level
    #
    @recursion_level += 1
    if @recursion_level > MAX_RECURSION_LEVEL
      $evm.log("info", "#{spaces}#{@method}:   Exceeded maximum recursion level")
      @recursion_level -= 1
      return
    end
    #
    # Make sure we haven't dumped this object already (some data structure links are cyclical)
    #
    this_object_id = this_object.id.to_s rescue this_object.object_id.to_s
    $evm.log("info", "#{spaces}#{@method}:   Debug: this_object.method_missing(:class) = #{this_object.method_missing(:class)}}") if @debug
    this_object_class = "#{this_object.method_missing(:class)}".demodulize
    $evm.log("info", "#{spaces}#{@method}:   Debug: this_object_class = #{this_object_class}") if @debug
    if @object_recorder.key?(this_object_class)
      if @object_recorder[this_object_class].include?(this_object_id)
        $evm.log("info", "#{spaces}#{@method}:   Object #{this_object_class} with ID #{this_object_id} has already been dumped...")
        @recursion_level -= 1
        return
      else
        @object_recorder[this_object_class] << this_object_id
      end
    else
      @object_recorder[this_object_class] = []
      @object_recorder[this_object_class] << this_object_id
    end
  
    if @recursion_level == 1
      $evm.log("info", "#{spaces}#{@method}:   Dumping $evm.root")
    end
    #
    # Write out the things of interest
    #
    dump_attributes(object_string, this_object, spaces)
    dump_virtual_columns(object_string, this_object, spaces)
    dump_associations(object_string, this_object, this_object_class, spaces)

    @recursion_level -= 1
  end
  #
  # Start with the root object
  #
  dump_object("$evm.root", $evm.root, "")
  #
  # Exit method
  #
  $evm.log("info", "#{@method} - EVM Automate Method Ended")
  exit MIQ_OK
  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "#{@method} - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
