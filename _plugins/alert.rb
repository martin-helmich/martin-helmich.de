class AlertTag < Liquid::Block
  CLS = 'fuck'
  ICON = 'you'

  def initialize(tag_name, heading, tokens)
    super
    @heading = heading
  end

  def render(context)
    contents = super
    <<-MARKUP.strip
    <div class="my-alert row #{self.class::CLS} white-text z-depth-1">
      <div class="col-sm-12">
        <span class="icon">
          <i class="fa fa-#{self.class::ICON}"></i>
        </span>
        <div class="my-alert-body">
          <strong>#{@heading}</strong> #{contents}
        </div>
      </div>
    </div>
    MARKUP
  end
end

class CautionTag < AlertTag
  CLS = 'warning-color-dark'
  ICON = 'exclamation-triangle'
end

class I18nHintTag < AlertTag
  CLS = 'info-color-dark'
  ICON = 'globe'
end

class UpdateTag < AlertTag
  CLS = 'default-color-dark'
  ICON = 'lightbulb'
end

class DangerTag < AlertTag
  CLS = 'danger-color-dark'
  ICON = 'fire'
end

Liquid::Template.register_tag('caution', CautionTag)
Liquid::Template.register_tag('i18nhint', I18nHintTag)
Liquid::Template.register_tag('update', UpdateTag)
Liquid::Template.register_tag('danger', DangerTag)
