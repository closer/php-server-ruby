#
# phphandler.rb -- PHPHandler Class
#
# This class is based on cgihandler.rb from the WEBrick bundle.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,
# BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
# IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

require 'rbconfig'
require 'tempfile'
require 'webrick'
require 'webrick/config'
require 'webrick/httpservlet/abstract'

module PHPServer
  include WEBrick

  class PHPHandler < HTTPServlet::AbstractServlet
    PHPCGI = 'php-cgi'
    PHPFPM = 'php-fpm'

    def initialize(server, name)
      super(server, name)
      @phpcmd = [PHPFPM, PHPCGI].map{|bin| File.join(@server[:PHPPath], bin) }.detect{|path| File.exist?(path) }
      @php_fullpath_script = name
      @logger.info("phpcmd: #{@phpcmd}")
    end

    def do_GET(req, res)
      data = nil
      status = -1

      meta = req.meta_vars
      meta["SCRIPT_FILENAME"] = @php_fullpath_script
      meta["REDIRECT_STATUS"] = "200" # php-cgi/apache specific value
      if /mswin|bccwin|mingw/ =~ RUBY_PLATFORM
        meta["SystemRoot"] = ENV["SystemRoot"]
      end
      meta["HTTP_SERVER_PORT"] = meta["SERVER_PORT"]
      meta["REQUEST_URI"] = meta["REQUEST_URI"].gsub /^https?:\/\/[^\/]+/, ''
      ENV.update(meta)

      require "open3"
      stdin, stdout, stderr, thr = Open3.popen3(ENV, @phpcmd)
      begin
        stdin.sync = true

        if req.body and req.body.bytesize > 0
          stdin.write(req.body)
        end
        stdin.close
      ensure
        data = stdout.read
        stdout.close
        stderr.close
        status = thr.value
        sleep 0.1 if /mswin|bccwin|mingw/ =~ RUBY_PLATFORM
      end

      @script_filename = meta['SCRIPT_NAME']
      if status != 0
        @logger.error("PHPHandler: #{@script_filename} exit with #{status}")
      end

      data = "" unless data
      raw_header, body = data.split(/^[\xd\xa]+/, 2)
      raise WEBrick::HTTPStatus::InternalServerError,
            "PHPHandler: Premature end of script headers: #{@script_filename}" if body.nil?

      begin
        header = WEBrick::HTTPUtils::parse_header(raw_header)
        if /^(\d+)/ =~ header['status'][0]
          res.status = $1.to_i
          header.delete('status')
        end
        if header.has_key?('location')
          # RFC 3875 6.2.3, 6.2.4
          res.status = 302 unless (300...400) === res.status
        end
        if header.has_key?('set-cookie')
          header['set-cookie'].each { |k|
            res.cookies << WEBrick::Cookie.parse_set_cookie(k)
          }
          header.delete('set-cookie')
        end
        header.each { |key, val| res[key] = val.join(", ") }
      rescue => ex
        raise WEBrick::HTTPStatus::InternalServerError, ex.message
      end
      res.body = body
    end

    alias do_POST do_GET
  end
end
