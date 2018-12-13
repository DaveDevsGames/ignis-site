module Jekyll
  require 'json'

  class TestPage < Page
    def initialize(site, base, dir, test_post)
      @site = site
      @base = base
      @dir = dir
      @name = test_post['title'].gsub(/\s+/, '').downcase << '.html'
      @content = test_post['content']

      self.process(@name)

      self.data = {}
      self.data['layout'] = 'post'
      self.data['title'] = test_post['title']
      self.data['author'] = test_post['author']
      self.data['image'] = test_post['image']
      self.data['blurb'] = test_post['blurb']
      self.data['creation_date'] = test_post['creation_date']
      self.data['updated_date'] = test_post['updated_date']
      self.data['published_date'] = test_post['published_date']
    end
  end

  class CategoryPageGenerator < Generator
    safe true

    def generate(site)
      test_hash = JSON.parse(File.read(File.join(__dir__, 'content-test.json')))
      dir = 'tests'
      for test_post in test_hash['posts']
        site.pages << TestPage.new(site, site.source, dir, test_post)
      end
    end
  end
end
