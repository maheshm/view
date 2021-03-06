require 'test_helper'
require 'support/reload_configuration_helper'
require 'ostruct'

describe Hanami::View do
  reload_configuration!

  describe 'rendering' do
    it 'renders a template' do
      HelloWorldView.render(format: :html).must_include %(<h1>Hello, World!</h1>)
    end

    it 'renders a template with context binding' do
      RenderView.render(format: :html, planet: 'Mars').must_include %(<h1>Hello, Mars!</h1>)
    end

    # See https://github.com/hanami/view/issues/76
    it 'renders a template with different encoding' do
      EncodingView.render(format: :html).must_include %(Configuração)
    end

    # See https://github.com/hanami/view/issues/76
    it 'raises error when given encoding is not correct' do
      exception = -> {
        Class.new do
          include Hanami::View
          configuration.default_encoding 'wrong'

          def self.name; 'EncodingView'; end
        end.render(format: :html)
      }.must_raise ArgumentError

      exception.message.must_include "unknown encoding name - wrong"
    end

    it 'renders a template according to the declared format' do
      JsonRenderView.render(format: :json, planet: 'Moon').must_include %("greet":"Hello, Moon!")
    end

    it 'renders a template according to the requested format' do
      articles = [ OpenStruct.new(title: 'Man on the Moon!') ]

      rendered = Articles::Index.render(format: :json, articles: articles)
      rendered.must_match %("title":"Man on the Moon!")

      rendered = Articles::Index.render(format: :html, articles: articles)
      rendered.must_match %(<h1>Man on the Moon!</h1>)
    end

    # this test was added to show that ../templates/members/articles/index.html.erb interferres with the normal behavior
    it 'renders the correct template when a subdirectory also exists' do
      articles = [ OpenStruct.new(title: 'Man on the Moon!') ]

      rendered = Articles::Index.render(format: :html, articles: articles)
      rendered.wont_match %(<h1>Wrong Article Template</h1>)
      rendered.must_match %(<h1>Man on the Moon!</h1>)

      rendered = Members::Articles::Index.render(format: :html, articles: articles)
      rendered.must_match %(<h1>Wrong Article Template</h1>)
      rendered.wont_match %(<h1>Man on the Moon!</h1>)
    end

    describe 'calling an action method from the template' do
      it 'can call with multiple arguments' do
        RenderViewMethodWithArgs.render({format: :html}).must_include %(<h1>Hello, earth!</h1>)
      end

      it 'will override Kernel methods' do
        RenderViewMethodOverride.render({format: :html}).must_include %(<h1>Hello, foo!</h1>)
      end

      it 'can call with block' do
        RenderViewMethodWithBlock.render({format: :html}).must_include %(<ul><li>thing 1</li><li>thing 2</li><li>thing 3</li></ul>)
      end
    end

    it 'binds given locals to the rendering context' do
      article = OpenStruct.new(title: 'Hello')

      rendered = Articles::Show.render(format: :html, article: article)
      rendered.must_match %(<h1>HELLO</h1>)
    end

    it 'renders a template from a subclass, if it is able to handle the requested format' do
      article = OpenStruct.new(title: 'Hello')

      rendered = Articles::Show.render(format: :json, article: article)
      rendered.must_match %("title":"olleh")
    end

    it 'raises an error when the template is missing' do
      article = OpenStruct.new(title: 'Ciao')

      -> {
        Articles::Show.render(format: :png, article: article)
      }.must_raise(Hanami::View::MissingTemplateError)
    end

    it 'raises an error when the format is missing' do
      -> {
        HelloWorldView.render({})
      }.must_raise(Hanami::View::MissingFormatError)
    end

    it 'renders different template, as specified by DSL' do
      article = OpenStruct.new(title: 'Bonjour')
      result  = OpenStruct.new(errors: {title: 'Title is required'})

      rendered = Articles::Create.render(format: :html, article: article, result: result)
      rendered.must_match %(<h1>New Article</h1>)
      rendered.must_match %(<h2>Errors</h2>)
    end

    it 'finds and renders template in nested directories' do
      rendered = NestedView.render(format: :html)
      rendered.must_match %(<h1>Nested</h1>)
    end

    it 'finds and renders partials in the directory of the view template parent directory' do
      rendered = Organisations::OrderTemplates::Action.render(format: :html)
      rendered.must_match %(Order Template Partial)
      rendered.must_match %(<div id="sidebar"></div>)

      rendered = Organisations::Action.render(format: :html)
      rendered.must_match %(Organisation Partial)
      rendered.must_match %(<div id="sidebar"></div>)
    end

    it 'decorates locals' do
      map = Map.new(['Rome', 'Cambridge'])

      rendered = Dashboard::Index.render(format: :html, map: map)
      rendered.must_match %(<h1>Map</h1>)
      rendered.must_match %(<h2>2 locations</h2>)
    end

    it 'safely ignores missing locals' do
      map = Map.new(['Rome', 'Cambridge'])

      rendered = Dashboard::Index.render(format: :html, map: map)
      rendered.wont_match %(<h3>Annotations</h3>)
    end

    it 'uses optional locals, if present' do
      map         = Map.new(['Rome', 'Cambridge'])
      annotations = OpenStruct.new(written?: true)

      rendered = Dashboard::Index.render(format: :html, annotations: annotations, map: map)
      rendered.must_match %(<h3>Annotations</h3>)
    end

    it 'renders a partial' do
      article = OpenStruct.new(title: nil)

      rendered = Articles::New.render(format: :html, article: article)

      rendered.must_match %(<h1>New Article</h1>)
      rendered.must_match %(<input type="hidden" name="secret" value="23" />)
    end

    it 'raises an error when the partial template is missing' do
      -> {
        RenderViewWithMissingPartialTemplate.render(format: :html)
      }.must_raise(Hanami::View::MissingTemplateError)
       .message.must_match("Can't find template 'shared/missing_template' for 'html' format.")
    end

    # @issue https://github.com/hanami/view/issues/3
    it 'renders a template within another template' do
      parent = OpenStruct.new(children: [], name: 'parent')
      child1 = OpenStruct.new(children: [], name: 'child1')
      child2 = OpenStruct.new(children: [], name: 'child2')

      parent.children.push(child1)
      parent.children.push(child2)

      rendered = Nodes::Parent.render(format: :html, node: parent)

      rendered.must_match %(<h1>parent</h1>)
      rendered.must_match %(<li>child1</li>)
      rendered.must_match %(<li>child2</li>)
    end

    it 'uses HAML engine' do
      person = OpenStruct.new(name: 'Luca')

      rendered = Contacts::Show.render(format: :html, person: person)
      rendered.must_match %(<h1>Luca</h1>)
      rendered.must_match %(<script type="text/javascript" src="/javascripts/contacts.js"></script>)
    end

    it 'uses Slim engine' do
      desk = OpenStruct.new(type: 'Standing')

      rendered = Desks::Show.render(format: :html, desk: desk)
      rendered.must_match %(<h1>Standing</h1>)
      rendered.must_match %(<script type="text/javascript" src="/javascripts/desks.js"></script>)
    end

    describe 'when without a template' do
      it 'renders from the custom rendering method' do
        song = OpenStruct.new(title: 'Song Two', url: '/song2.mp3')

        rendered = Songs::Show.render(format: :html, song: song)
        rendered.must_equal %(<audio src="/song2.mp3">Song Two</audio>)
      end

      it 'respond to all the formats' do
        rendered = Metrics::Index.render(format: :html)
        rendered.must_equal %(metrics)

        rendered = Metrics::Index.render(format: :json)
        rendered.must_equal %(metrics)
      end
    end

    describe 'layout' do
      it 'renders contents from layout' do
        articles = [ OpenStruct.new(title: 'A Wonderful Day!') ]

        rendered = Articles::Index.render(format: :html, articles: articles)
        rendered.must_match %(<h1>A Wonderful Day!</h1>)
        rendered.must_match %(<html>)
        rendered.must_match %(<title>Title: articles</title>)
      end

      it 'safely ignores missing locals' do
        articles = [ OpenStruct.new(title: 'A Wonderful Day!') ]

        rendered = Articles::Index.render(format: :html, articles: articles)
        rendered.wont_match %(<h2>Your plan is overdue.</h2>)
      end

      it 'uses optional locals, if present' do
        articles = [ OpenStruct.new(title: 'A Wonderful Day!') ]
        plan     =   OpenStruct.new(overdue?: true)

        rendered = Articles::Index.render(format: :html, plan: plan, articles: articles)
        rendered.must_match %(<h2>Your plan is overdue.</h2>)
      end
    end
  end
end
