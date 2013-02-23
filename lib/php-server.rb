require 'webrick'
require 'php-server/phphandler'

class PHPServer < WEBrick::HTTPServer
  def initialize *arg
    @rewrite_rules = []
    super
    mount '/', WEBrick::HTTPServlet::FileHandler, config[:DocumentRoot], :FancyIndexing => true, :HandlerTable => { 'php' => WEBrick::HTTPServlet::PHPHandler }
  end

  def rewrite pattern, subst
    @logger.info "rewrite rule #{pattern.inspect} -> #{subst}."
    @rewrite_rules << [pattern, subst]
  end

  def service req, res
    path = req.path
    @rewrite_rules.each do |pattern, subst|
      if pattern =~ path
        new_path = path.gsub pattern, subst
        @logger.info "rewrote url from #{path} to #{new_path}"
        req.instance_variable_set "@path", new_path
        break
      end
    end
    super req, res
  end
end
