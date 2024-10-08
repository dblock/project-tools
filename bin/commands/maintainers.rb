# frozen_string_literal: true

module Bin
  class Commands
    desc 'Data about repo maintainers.'
    command 'maintainers' do |g|
      g.flag %i[repo], multiple: true, desc: 'Search a specific repo within the org.'

      g.desc 'Show MAINTAINERS.md stats.'
      g.command 'stats' do |c|
        c.flag %i[date], desc: 'Date at.', default_value: nil
        c.action do |_global_options, options, _args|
          dt = options[:date] ? Chronic.parse(options[:date]).to_date : nil
          repos = if options[:repo]&.any?
                    GitHub::Repos.new(options[:repo])
                  else
                    GitHub::Organization.new(options.merge(org: options['org'] || 'opensearch-project')).repos
                  end
          maintainers = repos.maintainers(dt)
          puts "As of #{dt || Date.today}, #{repos.count} repos have #{maintainers.unique_count} maintainers, where #{maintainers.all_external_unique_percent}% (#{maintainers.all_external_unique_count}/#{maintainers.unique_count}) are external."
          puts "A total of #{repos.all_external_maintainers_percent}% (#{repos.all_external_maintained_size}/#{repos.count}) of repos have at least one of #{maintainers.all_external_unique_count} external maintainers."

          puts "\n# Member Maintainers\n"
          repos.member_maintained.each do |repo|
            puts "#{repo.html_url}: #{repo.maintainers.all_members} (#{repo.maintainers.all_members_unique_percent}%, #{repo.maintainers.all_members_unique_count}/#{repo.maintainers.unique_count})"
          end

          puts "\n# External Maintainers\n"
          repos.externally_maintained.each do |repo|
            puts "#{repo.html_url}: #{repo.maintainers.all_external} (#{repo.maintainers.all_external_unique_percent}%, #{repo.maintainers.all_external_unique_count}/#{repo.maintainers.unique_count})"
          end

          puts "\n# External Maintainers (Repos)\n"
          repos.external_maintainers.each_pair do |maintainer, repos_maintained|
            puts "#{maintainer}: #{repos_maintained.map(&:html_url).join(', ')}"
          end

          # GitHub::Maintainers::ALL_EXTERNAL.each do |bucket|
          #   repos.maintained[bucket]&.sort_by(&:name)&.each do |repo|
          #     puts "#{repo.html_url}: #{repo.maintainers.all_external} (#{repo.maintainers.all_external_unique_percent}%, #{repo.maintainers.all_external_unique_count}/#{repo.maintainers.unique_count})"
          #   end
          # end

          # puts "\n# All Maintainers\n"
          # puts "unique: #{maintainers.unique_count}"
          # maintainers.each_pair do |bucket, logins|
          #   puts "#{bucket}: #{logins.size} (#{logins.map(&:to_s).join(', ')})"
          # end

          # %i[external students contractors unknown].each do |bucket|
          #   next unless repos.maintained[bucket]&.any?

          #   puts "\n# #{bucket.capitalize} Maintainers\n"
          #   repos.maintained[bucket]&.sort_by(&:name)&.each do |repo|
          #     puts "#{repo.html_url}: #{repo.maintainers[bucket]}"
          #   end
          # end
        end
      end

      g.desc 'Audit repos for missing MAINTAINERS.md.'
      g.command 'missing' do |c|
        c.action do |_global_options, options, _args|
          repos = if options[:repo]&.any?
                    GitHub::Repos.new(options[:repo])
                  else
                    GitHub::Organization.new(options.merge(org: options['org'] || 'opensearch-project')).repos
                  end
          repos.sort_by(&:name).select { |repo| repo.maintainers.nil? }.each do |repo|
            puts repo.html_url
          end
        end
      end

      g.desc 'Audit MAINTAINERS.md and CODEOWNERS.'
      g.command 'audit' do |c|
        c.action do |_global_options, options, _args|
          repos = if options[:repo]&.any?
                    GitHub::Repos.new(options[:repo])
                  else
                    GitHub::Organization.new(options.merge(org: options['org'] || 'opensearch-project')).repos
                  end
          repos.sort_by(&:name).each do |repo|
            problems = {}
            repo.maintainers&.each do |user|
              next if repo.codeowners&.include?(user)

              problems[:missing_in_codeowners] ||= []
              problems[:missing_in_codeowners] << user
            end
            repo.codeowners&.each do |user|
              next if repo.maintainers&.include?(user)

              problems[:missing_in_maintainers] ||= []
              problems[:missing_in_maintainers] << user
            end
            next unless problems.any?

            puts "#{repo.html_url}: #{repo.maintainers&.count}"
            problems.each_pair do |k, v|
              puts " #{k}: #{v}" if v.any?
            end
          end
        end
      end

      g.desc 'Audit MAINTAINERS.md that have never contributed.'
      g.command 'contributors' do |c|
        c.action do |_global_options, options, _args|
          repos = if options[:repo]&.any?
                    GitHub::Repos.new(options[:repo])
                  else
                    GitHub::Organization.new(options.merge(org: options['org'] || 'opensearch-project')).repos
                  end
          total_users = 0
          total_repos = 0
          unique_users = Set.new
          repos.sort_by(&:name).each do |repo|
            users = repo.maintainers&.map do |user|
              commits = $github.commits(repo.full_name, author: user)
              next if commits.any?

              user
            end&.compact
            next unless users&.any?

            total_users += users.count
            total_repos += 1
            unique_users.add(users)
            puts "#{repo.html_url}: #{users}" if users&.any?
          end
          puts "\nThere are #{unique_users.count} unique names in #{total_users} instances of users listed in MAINTAINERS.md that have never contributed across #{total_repos}/#{repos.count} repos."
        end
      end

      g.desc 'Compare MAINTAINERS.md and CODEOWNERS with repo permissions.'
      g.command 'permissions' do |c|
        c.action do |_global_options, options, _args|
          repos = if options[:repo]&.any?
                    GitHub::Repos.new(options[:repo])
                  else
                    GitHub::Organization.new(options.merge(org: options['org'] || 'opensearch-project')).repos
                  end
          repos.sort_by(&:name).each do |repo|
            if repo.oss_problems.any?
              puts "#{repo.html_url}"
              repo.oss_problems.each_pair do |problem, desc|
                puts "  #{problem}: #{desc}"
              end
            else
              puts "#{repo.html_url}: OK"
            end
          end
        end
      end
    end
  end
end
