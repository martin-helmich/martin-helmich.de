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
    <div class="my-alert #{self.class::CLS}">
      <i class="glyphicon glyphicon-#{self.class::ICON}"></i>
      <div>
        <strong>#{@heading}</strong> #{contents}
      </div>
    </div>
    MARKUP
  end
end

class CautionTag < AlertTag
  CLS = 'caution'
  ICON = 'alert'
end

class I18nHintTag < AlertTag
  CLS = 'info'
  ICON = 'globe'
end

class DangerTag < AlertTag
  CLS = 'danger'
  ICON = 'fire'
end

Liquid::Template.register_tag('caution', CautionTag)
Liquid::Template.register_tag('i18nhint', I18nHintTag)
Liquid::Template.register_tag('danger', DangerTag)
