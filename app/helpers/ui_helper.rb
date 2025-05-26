module UiHelper
  def primary_button(label, options = {})
    classes = "bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
    options[:class] = [classes, options[:class]].compact.join(" ")
    content_tag(:button, label, options)
  end

  
  def form_group(form, field, type: :text_field, label: nil, **options)
    label ||= field.to_s.humanize
    content_tag(:div, class: "space-y-1") do
      form.label(field, label, class: "block text-sm font-medium text-gray-700") +
      form.send(type, field, class: "mt-1 block w-full rounded border-gray-300 shadow-sm", **options)
    end
  end

  def form_select_group(form, field, collection, value_method, label_method, label: nil, **options)
    label ||= field.to_s.humanize
    content_tag(:div, class: "space-y-1") do
        form.label(field, label, class: "block text-sm font-medium text-gray-700") +
        form.collection_select(field, collection, value_method, label_method, { prompt: "Selecione" }, class: "mt-1 block w-full rounded border-gray-300 shadow-sm", **options)
    end
  end
end
