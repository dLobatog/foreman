module LookupKeysHelper
  def remove_child_link(name, f, opts = {})
    opts[:class] = [opts[:class], "remove_nested_fields"].compact.join(" ")
    f.hidden_field(opts[:method]||:_destroy) + link_to_function(name, "remove_child_node(this);", opts)
  end

  def delete_child_link(name, f, opts = {})
    opts[:class] = [opts[:class], "remove_nested_fields"].compact.join(" ")
    link_to_function(name, "delete_child_node(this);", opts)
  end

  def add_child_link(name, association, opts = {})
    opts[:class] = [opts[:class], "add_nested_fields btn btn-success"].compact.join(" ")
    opts[:"data-association"] = association
    link_to_function(name.to_s, "add_child_node(this);", opts)
  end

  def new_child_fields_template(form_builder, association, options = { })
    options[:object]             ||= form_builder.object.class.reflect_on_association(association).klass.new
    options[:partial]            ||= association.to_s.singularize
    options[:form_builder_local] ||= :f
    options[:form_builder_attrs] ||= {}

    content_tag(:div, :class => "#{association}_fields_template form_template", :style => "display: none;") do
      form_builder.fields_for(association, options[:object], :child_index => "new_#{association}") do |f|
        render(:partial => options[:partial],
               :layout => options[:layout],
               :locals => { options[:form_builder_local] => f }.merge(options[:form_builder_attrs]))
      end
    end
  end

  def show_puppet_class(f)
    # In case of a new smart-var inside a puppetclass (REST nesting only), or a class parameter:
    # Show the parent puppetclass as a context, but permit no change.
    if params["puppetclass_id"]
      select_f f, :puppetclass_id, [Puppetclass.find(params["puppetclass_id"])], :id, :to_label, {}, {:label => _("Puppet class"), :disabled => true}
    elsif f.object.puppet? && f.object.param_class
      text_f(f, :puppetclass_id, :label => _('Puppet Class'), :value => f.object.param_class, :disabled => true)
    else # new smart-var with no particular context
         # Give a select for choosing the parent puppetclass
      select_f(f, :puppetclass_id, Puppetclass.all, :id, :to_label, { :include_blank => _('None') }, {:label => _("Puppet class")})
    end unless @puppetclass # nested smart-vars form in a tab of puppetclass/_form: no edition allowed, and the puppetclass is already visible as a context
  end

  def param_type_selector(f, options = {})
    selectable_f f, :key_type, options_for_select(LookupKey::KEY_TYPES.map { |e| [_(e),e] }, f.object.key_type),{},
                 options.merge({ :disabled => (f.object.puppet? && !f.object.override), :size => "col-md-8", :class=> "without_select2",
                 :help_inline => popover("",_("<dl>" +
               "<dt>String</dt> <dd>Everything is taken as a string.</dd>" +
               "<dt>Boolean</dt> <dd>Common representation of boolean values are accepted.</dd>" +
               "<dt>Integer</dt> <dd>Integer numbers only, can be negative.</dd>" +
               "<dt>Real</dt> <dd>Accept any numerical input.</dd>" +
               "<dt>Array</dt> <dd>A valid JSON or YAML input, that must evaluate to an array.</dd>" +
               "<dt>Hash</dt> <dd>A valid JSON or YAML input, that must evaluate to an object/map/dict/hash.</dd>" +
               "<dt>YAML</dt> <dd>Any valid YAML input.</dd>" +
               "<dt>JSON</dt> <dd>Any valid JSON input.</dd>" +
               "</dl>"), :title => _("How values are validated")).html_safe})
  end

  def validator_type_selector(f)
    selectable_f f, :validator_type, options_for_select(LookupKey::VALIDATOR_TYPES.map { |e| [_(e),e]  }, f.object.validator_type),{:include_blank => _("None")},
               { :disabled => (f.object.puppet? && !f.object.override), :size => "col-md-8", :class=> "without_select2",
                 :onchange => 'validatorTypeSelected(this)',
                 :help_inline => popover("",_("<dl>" +
               "<dt>List</dt> <dd>A list of the allowed values, specified in the Validator rule field.</dd>" +
               "<dt>Regexp</dt> <dd>Validates the input with the regular expression in the Validator rule field.</dd>" +
               "</dl>"), :title => _("Validation types")).html_safe}
  end

  def overridable_lookup_keys(klass, host)
    klass.class_params.override.where(:environment_classes => {:environment_id => host.environment}) + klass.lookup_keys
  end

  def can_edit_params?
    authorized_via_my_scope('host_editing', 'edit_params')
  end

  def can_remove_params?
    authorized_via_my_scope('host_editing', 'destroy_params')
  end

  def find_lookup_value(obj, lookup_key_id)
    obj.lookup_values.find_or_initialize(:lookup_key_id => lookup_key_id)
  end

  def lookup_key_with_diagnostic(obj, lookup_key, index, lookup_value)
    value, matcher = lookup_value_and_matcher(obj, lookup_key)

    original_value = lookup_key.value_before_type_cast value
    overriden_value = lookup_value.try(:value)
    no_value = value.blank? && overriden_value.blank?

    explanation = _("<b>Description:</b> %{desc}<br/>
                     <b>Type:</b> %{type}<br/>
                     <b>Matcher:</b> %{matcher}<br/>
                     <b>Inherited value:</b> %{original_value}") %
                    { :desc => lookup_key.description, :type => lookup_key.key_type,
                      :matcher => matcher, :original_value => original_value }
    if no_value && obj.class.model_name == "Host"
      if lookup_key.required
        explanation.prepend(_("Required parameter without value.<br/><b>Please override!</b><br/>"))
        icon = "warning-sign"
      else
        explanation.prepend(_("Optional parameter without value.<br/><i>Won't be given to Puppet.</i><br/>"))
        icon = "exclamation-sign"
      end
    end
    diagnostic_helper = popover('', explanation, :data => { :placement => 'top' }, :title => _("Original value info"), :icon => icon)

    value_for_form = overriden_value.nil? ? original_value : overriden_value
    parameter_value_content("#{obj.class.model_name.downcase}_lookup_values_attributes_#{index}_value",
                            value_for_form,
                            { :popover => diagnostic_helper,
                              :name => "#{obj.class.model_name.downcase}[lookup_values_attributes][#{index}][value]",
                              :disabled => !lookup_key.overridden?(obj) || lookup_value.try(:use_puppet_default),
                              :original_value => original_value
                            })
  end

  def edit_lookup_key_parameter(value_prefix, lookup_key, lookup_value)
    return '' unless can_edit_params?
    hidden_field(value_prefix, :lookup_key_id, :value => lookup_key.id, :disabled => disabled, :class => 'send_to_remove') +
    hidden_field(value_prefix, :id, :value => lookup_value.try(:id), :disabled => disabled, :class => 'send_to_remove')
  end

  def remove_lookup_key_parameter(value_prefix)
    return '' unless can_remove_params?
    hidden_field(value_prefix, :_destroy, :value => false, :disabled => disabled, :class => 'send_to_remove destroy')
  end

  def override_buttons(can_edit, overridden)
    return unless can_edit
    link_to_function(icon_text('edit'), "override_class_param(this)", :title => _("Override this value"),
                         :'data-tag' => 'override', :class =>"btn btn-default btn-md #{'hide' if overridden}") +
      link_to_function(icon_text('remove'), "override_class_param(this)", :title => _("Remove this override"),
                         :'data-tag' => 'remove', :class =>"btn btn-default btn-md #{'hide' unless overridden}")
  end
end
