module UiHelper
  def primary_button(label, options = {})
    classes = "btn btn-primary"
    options[:class] = [classes, options[:class]].compact.join(" ")
    content_tag(:button, label, options)
  end
  
  def form_group(form, field, type: :text_field, label: nil, choices: nil, **options)
    label ||= field.to_s.humanize
    content_tag(:div, class: "form-control") do
      form.label(field, label, class: "label") +
        if type == :select
          form.select(field, choices, {}, class: "select select-bordered w-full", **options)
        else
          form.send(type, field, class: "input input-bordered w-full", **options)
        end
    end
  end

  def form_select_group(form, field, collection, value_method, label_method, label: nil, **options)
    label ||= field.to_s.humanize
    content_tag(:div, class: "form-control") do
        form.label(field, label, class: "label") +
        form.collection_select(field, collection, value_method, label_method, { prompt: "Selecione" }, class: "select select-bordered w-full", **options)
    end
  end
end
