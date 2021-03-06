class TreeBuilder
  include Sandbox
  include CompressedIds
  attr_reader :locals_for_render, :name, :type

  #need to move this to a subclass
  def self.root_options(tree_name)
    #returns title, tooltip, root icon
    case tree_name
    when :ab_tree                       then ["Object Types",                 "Object Types"]
    when :ae_tree                       then ["Datastore",                    "Datastore"]
    when :automate_tree                 then ["Datastore",                    "Datastore"]
    when :bottlenecks_tree, :utilization_tree             then
      if MiqEnterprise.my_enterprise.is_enterprise?
        title = "Enterprise"
        icon = "enterprise"
      else
        title = "CFME Region: #{MiqRegion.my_region.description} [#{MiqRegion.my_region.region}]"
        icon = "miq_region"
      end
      [title, title, icon]
    when :cb_assignments_tree           then ["Assignments",                  "Assignments"]
    when :cb_rates_tree                 then ["Rates",                        "Rates"]
    when :cb_reports_tree               then ["Saved Chargeback Reports",     "Saved Chargeback Reports"]
    when :customization_templates_tree  then
      title = "All #{ui_lookup(:models => "CustomizationTemplate")} - #{ui_lookup(:models => "PxeImageType")}"
      [title, title]
    when :diagnostics_tree, :rbac_tree, :settings_tree     then
      region = MiqRegion.my_region
      ["CFME Region: #{region.description} [#{region.region}]", "CFME Region: #{region.description} [#{region.region}]", "miq_region"]
    when :dialogs_tree                  then ["All Dialogs",                  "All Dialogs"]
    when :dialog_import_export_tree     then ["Service Dialog Import/Export", "Service Dialog Import/Export"]
    when :images_tree                   then ["Images by Provider",           "All Images by Provider that I can see"]
    when :instances_tree                then ["Instances by Provider",        "All Instances by Provider that I can see"]
    when :instances_filter_tree         then ["All Instances",                "All of the Instances that I can see"]
    when :images_filter_tree            then ["All Images",                   "All of the Images that I can see"]
    when :iso_datastores_tree           then ["All ISO Datastores",           "All ISO Datastores"]
    when :old_dialogs_tree              then ["All Dialogs",                  "All Dialogs"]
    when :pxe_image_types_tree          then ["All System Image Types",       "All System Image Types"]
    when :pxe_servers_tree              then ["All PXE Servers",              "All PXE Servers"]
    when :sandt_tree                    then ["All Catalog Items",            "All Catalog Items"]
    when :stcat_tree                    then ["All Catalogs",                 "All Catalogs"]
    when :svccat_tree                   then ["All Services",                 "All Services"]
    when :svcs_tree                     then ["All Services",                 "All Services"]
    when :vandt_tree                    then ["All VMs & Templates",          "All VMs & Templates that I can see"]
    when :vms_filter_tree               then ["All VMs",                      "All of the VMs that I can see"]
    when :templates_filter_tree         then ["All Templates",                "All of the Templates that I can see"]
    when :vms_instances_filter_tree     then ["All VMs & Instances",          "All of the VMs & Instances that I can see"]
    when :templates_images_filter_tree  then ["All Templates & Images",       "All of the Templates & Images that I can see"]
    when :vmdb_tree                     then ["VMDB",                         "VMDB", "miq_database"]
    end
  end

  def initialize(name, type, sandbox)
    @locals_for_render  = {}
    @name               = name.to_sym
    @options            = tree_init_options(name.to_sym)
    @sb                 = sandbox
    @tree_nodes         = {}
    @type               = type.to_sym
    build_tree
  end

  # return this nodes model and record id
  def extract_method_and_node_id(id)
    id.split("_").last.split('-')
  end

  # Get the children of a dynatree node that is being expanded (autoloaded)
  def x_get_child_nodes_dynatree(id)
    prefix, rec_id = extract_method_and_node_id(id)
    model = X_TREE_NODE_PREFIXES[prefix]                # Get this nodes model (folder, Vm, Cluster, etc)
    if model == "Hash"
      object = {:type => prefix, :id => rec_id, :full_id => id}
    elsif model.nil? && [:sandt_tree, :svccat_tree, :stcat_tree].include?(x_active_tree)
      # Creating empty record to show items under unassigned catalog node
      object = ServiceTemplateCatalog.new # Get the object from the DB
    else
      object = model.constantize.find(from_cid(rec_id))   # Get the object from the DB
    end

    kids = Array.new
    x_tree[:open_nodes].push(id) unless x_tree[:open_nodes].include?(id) # Save node as open

    options = x_tree         # Get options from sandbox

    # Process the node's children
    x_get_tree_objects(options.merge(:parent => object)).each do |o|
      kids += x_build_node_dynatree(o, id, options)
    end

    return kids                                         # Return the node's children
  end

  private

  def build_tree
    add_to_sandbox
    tree_nodes = x_build_dynatree(x_tree(@name))
    active_node_set(tree_nodes)
    set_nodes(tree_nodes)
  end

  #subclass this method if active node on initial load is different than root node
  def active_node_set(tree_nodes)
    x_node_set(tree_nodes.first[:key], @name) unless x_node(@name)  # Set active node to root if not set
  end

  def set_nodes(nodes)
    add_root_node(nodes)
    @tree_nodes = nodes.to_json
    @locals_for_render = set_locals_for_render
  end

  def add_to_sandbox
    @sb[:trees] ||= {}
    unless @sb.has_key_path?(:trees, @name)
      values = @options.reverse_merge(
          :tree       => @name,
          :type       => type,
          :klass_name => self.class.name,
          :leaf       => @options[:leaf],
          :add_root   => true,
          :open_nodes => []
      )
      @sb.store_path(:trees, @name, values)
    end
  end

  def add_root_node(nodes)
    root = nodes.first
    root[:title], root[:tooltip], icon = TreeBuilder.root_options(@name)
    root[:icon] = "#{icon || 'folder'}.png"
  end

  def set_locals_for_render
    {
      :tree_id        => "#{@name}box",
      :tree_name      => @name.to_s,
      :json_tree      => @tree_nodes,
      :select_node    => "#{x_node(@name)}",
      :onclick        => "cfmeOnClick_SelectTreeNode",
      :id_prefix      => "#{@name.to_s}_",
      :base_id        => "root",
      :no_base_exp    => true,
      :exp_tree       => false,
      :highlighting   => true,
      :tree_state     => true,
      :multi_lines    => true
    }
  end

  # Build an explorer tree, from scratch
  # Options:
  # :type                   # Type of tree, i.e. :handc, :vandt, :filtered, etc
  # :leaf                   # Model name of leaf nodes, i.e. "Vm"
  # :open_nodes             # Tree node ids of currently open nodes
  # :add_root               # If true, put a root node at the top
  # :full_ids               # stack parent id on top of each node id
  def x_build_dynatree(options)
    roots = x_get_tree_objects(options.merge(
      :userid => User.current_user, # Userid for RBAC filtering
      :parent => nil                # Asking for roots, no parent
    ))

    root_nodes = roots.each_with_object([]) { |root, acc| acc.concat(x_build_node_dynatree(root, nil, options)) }

    return root_nodes unless options[:add_root]
    [{:key => 'root', :children => root_nodes, :expand => true}]
  end

  # Get objects (or count) to put into a tree under a parent node, based on the tree type
  # TODO: Make the called methods honor RBAC for passed in userid
  # TODO: Perhaps push the object sorting down to SQL, if possible
  # Options used:
  # :parent                 # Parent object for which we need child tree nodes returned
  # :userid                 # Signed in user's id
  # :count_only             # Return only the count if true
  # :type                   # Type of tree, i.e. :handc, :vandt, :filtered, etc
  # :leaf                   # Model name of leaf nodes, i.e. "Vm"
  # :open_all               # if true open all node (no autoload)
  def x_get_tree_objects(options)
    object = options[:parent]
    children_or_count = case object
                        when nil                 then x_get_tree_roots(options)
                        when CustomButtonSet     then x_get_tree_aset_kids(object, options)
                        when Dialog              then x_get_tree_dialog_kids(object, options)
                        when DialogGroup         then x_get_tree_dialog_group_kids(object, options)
                        when DialogTab           then x_get_tree_dialog_tab_kids(object, options)
                        when ExtManagementSystem then x_get_tree_ems_kids(object, options)
                        when EmsFolder           then if object.is_datacenter
                                                        x_get_tree_datacenter_kids(object, options)
                                                      else
                                                        x_get_tree_folder_kids(object, options)
                                                      end
                        when EmsCluster          then x_get_tree_cluster_kids(object, options)
                        when Hash                then x_get_tree_custom_kids(object, options)
                        when IsoDatastore        then x_get_tree_iso_datastore_kids(object, options)
                        when LdapRegion          then x_get_tree_lr_kids(object, options)
                        when MiqAeClass          then x_get_tree_class_kids(object, options)
                        when MiqAeNamespace      then x_get_tree_ns_kids(object, options)
                        when MiqGroup            then options[:tree] == :db_tree ?
                                                    x_get_tree_g_kids(object, options) : nil
                        when MiqRegion           then x_get_tree_region_kids(object, options)
                        when PxeServer           then x_get_tree_pxe_server_kids(object, options)
                        when ServiceTemplateCatalog
                                                 then x_get_tree_stc_kids(object, options)
                        when ServiceTemplate		 then x_get_tree_st_kids(object, options)
                        when VmdbTableEvm        then x_get_tree_vmdb_table_kids(object, options)
                        when Zone                then x_get_tree_zone_kids(object, options)
                        end
    children_or_count || (options[:count_only] ? 0 : [])
  end

  # Return a tree node for the passed in object
  def x_build_node(object, pid, options, dynatree = false)    # Called with object, tree node parent id, tree options
    @sb[:my_server_id] = MiqServer.my_server(true).id      if object.kind_of?(MiqServer)
    @sb[:my_zone]      = MiqServer.my_server(true).my_zone if object.kind_of?(Zone)

    options[:is_current] =
        ((object.kind_of?(MiqServer) && @sb[:my_server_id] == object.id) ||
         (object.kind_of?(Zone)      && @sb[:my_zone]      == object.name))
    options.merge!(:active_tree => x_active_tree)

    # open nodes to show selected automate entry point
    x_tree[:open_nodes] = @temp[:open_nodes].dup if @temp && @temp[:open_nodes]

    builder_class = dynatree ? TreeNodeBuilderDynatree : TreeNodeBuilderDHTMLX
    node = builder_class.build(object, pid, options)

    if dynatree
      # FIXME: missing this for non-dynatree
      x_tree(options[:tree])[:open_nodes].push(node[:key]) if [:policy_profile_tree, :policy_tree].include?(options[:tree])
    else
      # FIXME: missing this for dynatree
      node['select'] = 1 if x_node(options[:tree]) == node['id']
    end

    # Process the node's children
    key_name = dynatree ? :key : 'id'
    if x_tree[:open_nodes].include?(node[key_name]) || options[:open_all] || object[:load_children] || node[:expand]
      kids = x_get_tree_objects(options.merge(:parent => object)).each_with_object([]) do |o, acc|
        acc.concat(x_build_node(o, node[key_name], options, dynatree))
      end
      node[dynatree ? :children : 'item'] = kids unless kids.empty?
    else
      if x_get_tree_objects(options.merge({:parent => object, :count_only => true})) > 0
        if dynatree
          node[:isLazy] = true  # set child flag if children exist
        else
          node['child'] = '1' # set child flag if children exist
        end
      end
    end
    [node]
  end

  def x_build_node_dynatree(object, pid, options)   # Called with object, tree node parent id, tree options
    x_build_node(object, pid, options, true)
  end

  # Handle custom tree nodes (object is a Hash)
  def x_get_tree_custom_kids(object, options)
    options[:count_only] ? 0 : []
  end

  #add child nodes to the active tree below node 'id'
  def self.tree_add_child_nodes(sandbox, klass_name, id)
    tree = klass_name.constantize.new("temp_tree", "temp", sandbox)
    tree.x_get_child_nodes_dynatree(id)
  end

  def count_only_or_objects(count_only, objects, sort_by)
    if count_only
      objects.count
    elsif sort_by
      objects.sort_by { |o| Array(sort_by).collect { |sb| o.deep_send(sb).to_s.downcase } }
    else
      objects
    end
  end

  #Replacing calls to VMDB::Config.new in the views/controllers
  def get_vmdb_config
    @vmdb_config ||= VMDB::Config.new("vmdb").config
  end

  def rbac_filtered_objects(objects, options = {})
    return objects if objects.empty?

    # Uncomment the following line to skip filtering for parent nodes (i.e. show V&T tree like admin sees it with all nodes)
    #    return objects unless objects.first.is_a?(VmOrTemplate)

    descendant_model = nil

    # Remove VmOrTemplate :match_via_descendants option if present, comment to let Rbac.search process it
    descendant_model = options.delete(:match_via_descendants) if options[:match_via_descendants] == "VmOrTemplate"

    options.merge!(:targets => objects, :results_format => :objects)
    results, attrs = Rbac.search(options)

    # If we are processing :match_via_descendants and user is filtered (i.e. not like admin/super-admin)
    if descendant_model && User.current_user_has_filters?
      results = objects.select do |o|
        keep = true
        if o.is_a?(EmsFolder) ||  # If it's a folder object, see if it has any descendants
            !results.include?(o)  # If search removed it, see if it has any descendants
          process_show_list(:model => "VmOrTemplate", :association => "all_vms_and_templates", :parent => o)  # Fetch the report records
          keep = !@view.table.data.empty?  # Keep only if descendants present
        end
        keep
      end
    end

    results
  end
end
