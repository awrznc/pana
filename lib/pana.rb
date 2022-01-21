module Pana
  require 'date'
  require 'logger'
  require 'yaml'

  require 'pana/result'
  require 'pana/service'
  require 'pana/system'

  require 'pana/system/git'
  include Git

  class Analyzer

    def initialize(target: '', verbose: false)
      @verbose = verbose
      @logger = Logger.new(STDOUT)

      parsed_object = parse_target(target)
      raise "pana: parse error. ( #{parsed_object.message} )" unless parsed_object.ok?
      @service_name, @account_type, @account_name, @token = parsed_object.result

      @date_range_from  = DateTime.parse('2021-01-01T00:00:00Z')
      @date_range_to    = DateTime.parse('2021-12-31T23:59:59Z')

      case @service_name
      when 'github'
        @service = GitHub.new(github_access_token: @token)
      else
        raise 'unknown case.'
      end

      @project_names = Array.new
      self.get_project_names
    end

    def get_project_name(index, loop_number)
      @service.get_repos(@account_type, @account_name, 100, index).each do |repository|
        @project_names.push(repository['full_name']) if DateTime.parse(repository['updated_at']).between?(@date_range_from, @date_range_to)
      end
      @logger.info("got repository names (#{index}/#{loop_number}[page])") if @verbose
    end

    def get_project_names

      total_repo_number = self.get_total_repository_count
      @logger.info("repository count = #{total_repo_number}") if @verbose

      @project_names = Array.new
      loop_number = (total_repo_number/100)+1

      (1..loop_number).map do |index|
        # Ractor.new(self, index, loop_number) do |analyzer, idx, loop_num|
        #   analyzer.get_project_name(idx, loop_num)
        # end
        Thread.new do
          self.get_project_name(index, loop_number)
        end
      # end.each(&:take)
      end.each(&:join)

      return @project_names
    end

    def clone_projects(dir)
      @project_names.each_with_index do |target, index|
        @logger.info("[#{index+1}/#{@project_names.length}] Cloning #{target}") if @verbose
        Git::clone("git@github.com:#{target}.git", "#{dir}/#{target}")
      end
      # target = "git@github.com:#{@project_names[0]}.git"
      # @logger.info("Cloning #{@project_names[0]}") if @verbose
      # Git::clone(target, "#{dir}/#{@project_names[0]}")
    end

    def analyze(dir)
      projects_path = Array.new
      Dir.glob("#{dir}/*") do |account|
        if FileTest.directory?(account) then
          Dir.glob("#{account}/*") do |project|
            projects_path.push(project) if FileTest.directory?(project)
          end
        end
      end

      users = Hash.new
      projects_path.each.with_index do |project, index|
        Git::shortlog(project).split("\n").map do |shortlog|
          user_info = shortlog.match(/^[^\d]+(\d+)\t(.+)\s<(.+@.+)>$/).to_a
          users[user_info.last] ||= { names: Array.new, commit_count: 0, type: { } }

          unless users[user_info.last][:names].include?(user_info[2]) then
            users[user_info.last][:names].push(user_info[2])

            Git::log(project, user_info[2]).split("\n").map do |log|
              user_log_info = log.match(/^([^\s]+)\s+([^\s]+)[\s|\"]+([^(\s|\")]+).*$/).to_a
              file_elements = user_log_info.last.split('.')
              file_type = file_elements.length > 1 ? file_elements.last : 'other'
              users[user_info.last][:type][file_type] ||= { add: 0, delete: 0 }
              users[user_info.last][:type][file_type][:add] += user_log_info[1].to_i
              users[user_info.last][:type][file_type][:delete] += user_log_info[2].to_i
            end
          end
          users[user_info.last][:commit_count] += user_info[1].to_i
        end

        @logger.info("[#{index+1}/#{projects_path.length}] got repository information. ( #{project.split('/').last} )")
      end

      File.open("#{dir}/result.yaml", mode = "a") do |file|
        file.write(users.to_yaml)
      end
    end

    private

    def get_total_repository_count
      response = @service.get_account_information(@account_type, @account_name)
      return response['owned_private_repos'].to_i + response['public_repos'].to_i
    end

    def parse_target(target_string)
      return Result.new( nil, 'type error' ) if target_string.class != String

      match_result = target_string.match(/^(github)\/(users|orgs)\/(.+?):(.+)$/m)
      return Result.new( nil, 'nil error' ) if match_result == nil

      match_result_array = match_result.to_a
      return Result.new( nil, 'length error' ) if match_result_array.length != (4 + 1)

      return Result.new( match_result_array[1..-1], nil )
    end
  end
end
