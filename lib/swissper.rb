require 'swissper/version'
require 'swissper/player'
require 'swissper/bye'
require 'graph_matching'

module Swissper
  def self.pair(players, options = {})
    Pairer.new(options).pair(players)
  end

  class Pairer
    def initialize(options = {})
      @delta_key = options[:delta_key] || :delta
      @side_delta_key = options[:side_delta_key] || :side_delta
      @exclude_key = options[:exclude_key] || :exclude
      @bye_delta = options[:bye_delta] || -1,
      @score_factor = options[:score_factor] || 1
      @single_sided =  options[:single_sided] || false
    end

    def pair(player_data)
      @player_data = player_data
      graph.maximum_weighted_matching(true).edges.map do |pairing|
        [players[pairing[0]], players[pairing[1]]]
      end
    end

    private

    attr_reader :delta_key, :side_delta_key, :exclude_key, :bye_delta, :score_factor

    def graph
      edges = [].tap do |e|
        players.each_with_index do |player, i|
          players.each_with_index do |opp, j|
            e << [i, j, delta(player,opp)] if permitted?(player, opp)
          end
        end
      end
      GraphMatching::Graph::WeightedGraph.send('[]', *edges)
    end

    def permitted?(a, b)
      targets(a).include?(b) && targets(b).include?(a)
    end

    def delta(a, b)
      0 - delta_factor(a,b) - side_delta_factor(a, b)
    end

    def delta_factor(a, b)
      (delta_value(a) - delta_value(b))**2 * @score_factor
    end

    def side_delta_factor(a,b)
      return 0 unless @single_sided
      return 0 if side_delta_value(a) * side_delta_value(b) <= 0 # always return 0 if they aren't biased in the same direction

      ([side_delta_value(a).abs, side_delta_value(b).abs].min*4)**3
    end

    def targets(player)
      players - [player] - excluded_opponents(player)
    end

    def delta_value(player)
      return player.send(delta_key) if player.respond_to?(delta_key)
      return bye_delta if player == Swissper::Bye

      0
    end

    def side_delta_value(player)
      return player.send(side_delta_key) if player.respond_to?(side_delta_key)
      0
    end

    def excluded_opponents(player)
      return player.send(exclude_key) if player.respond_to?(exclude_key)

      []
    end

    def players
      @players ||= @player_data.clone.tap do |data|
        data << Swissper::Bye unless data.length.even?
      end.shuffle
    end
  end
end
