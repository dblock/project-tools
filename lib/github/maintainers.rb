# frozen_string_literal: true

module GitHub
  class Maintainers < Array
    include GitHub::Buckets

    ALL_EXTERNAL = %i[contractors external students].freeze

    def buckets
      @buckets ||= begin
        buckets = {}
        each do |user|
          bucket = GitHub::Contributors.bucket(user)
          buckets[bucket] ||= []
          buckets[bucket] << user
        end
        buckets
      end
    end

    def all_external
      ALL_EXTERNAL.map do |bucket|
        buckets[bucket]
      end.flatten.uniq.compact
    end

    def all_external_unique_percent
      return 0 unless unique_count

      ((all_external_unique_count.to_f / unique_count) * 100).round(1)
    end

    def all_members_unique_percent
      return 0 unless unique_count

      ((all_members_unique_count.to_f / unique_count) * 100).round(1)
    end

    def unique_count
      buckets.values.flatten.uniq.size
    end

    def all_external_unique_count
      ALL_EXTERNAL.map do |bucket|
        buckets[bucket]
      end.compact.flatten.uniq.size
    end

    def all_members_unique_count
      buckets[:members].uniq.size
    end

    def each_pair(&_block)
      buckets.each_pair(&_block)
    end

    def [](bucket)
      buckets[bucket]
    end
  end
end
