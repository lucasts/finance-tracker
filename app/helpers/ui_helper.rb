module UiHelper
  def primary_button(label, options = {})
    classes = "btn btn-primary"
    options[:class] = [ classes, options[:class] ].compact.join(" ")
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

  def status_badge(status, text = nil)
    case status
    when "active", "confirmed", "completed", true
      badge_class = "badge-success"
      icon = '<svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" /></svg>'
    when "inactive", "pending", false
      badge_class = "badge-warning"
      icon = '<svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>'
    when "cancelled", "error"
      badge_class = "badge-error"
      icon = '<svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg>'
    else
      badge_class = "badge-neutral"
      icon = ""
    end

    text ||= status.to_s.humanize
    content_tag :span, class: "badge #{badge_class} gap-1" do
      icon.html_safe + text
    end
  end

  def import_status_icon(status)
    case status
    when "completed"
      '<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>'.html_safe
    when "pending"
      '<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-warning" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>'.html_safe
    else
      '<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-neutral" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>'.html_safe
    end
  end
end
