#!/usr/bin/env ruby

class G2Grep
  def initialize(query, path_prefix=nil)
    @query = query.split
  end
  
  def parsed(&block)
    @block = block
    @parsed ||= eval_expr(@query)
    @parsed
  end

  # EXPR = EXPR_OR
  # EXPR_OR = EXPR_AND ( 'or' EXPR_AND )*
  # EXPR_AND = EXPR_IAND ( 'and' EXPR_IAND )*
  # EXPR_IAND = EXPR_NOT ( EXPR_NOT )*
  # EXPR_NOT = 'not' EXPRNOT
  #          | EXPR_PAR
  # EXPR_PAR = '(' EXPR_OR ')'
  #          | STR
  # STR = 文字列
  
  private
  
  class QStateBack < Exception; end
  
  class QState
    def initialize(args)
      q = args[:q]
      @parent = args[:parent]
      @initial_pos = @parent.nil? ? 0 : @parent.pos
      @pos = @initial_pos
      @q = q ? q : @parent.q
    end
    def get_next_token
      if @pos >= @q.length
        return nil
      end
      tok = @q[@pos]
      @pos += 1
      tok
    end
    def save
      QState.new(parent: self)
    end
    def restore
      @pos = @initial_pos
    end
    def finish
      @parent.pos = @pos
    end
    def next_token_is(s)
      if @pos >= @q.length
        return false
      end
      if @q[@pos] == s
        @pos += 1
        return true
      end
      false
    end
    def next_token_is_keyword
      if @pos >= @q.length
        return true
      end
      return [ 'or', 'and', 'not', '(', ')' ].include? @q[@pos]
    end
    def throw
      raise QStateBack.new
    end
    def is_empty
      @pos >= @q.length
    end
    def pos
      @pos
    end
    def pos=(p)
      @pos = p
    end
    def q
      @q
    end
  end
  
  def eval_expr(q)
    q = QState.new(q: q)
    r = eval_expr_or(q)
    unless q.is_empty
      raise RuntimeError.new('syntax error.')
    end
    r
  end
  
  def eval_expr_or(q)
    begin
      q = q.save
      r = eval_expr_and(q)
      if r.nil?
        q.throw
      end
      ary = r
      while q.next_token_is('or')
        s = eval_expr_and(q)
        if s.nil?
          break
        end
        ary = ary.union(s)
      end
      ary
    rescue QStateBack
      q.restore
      nil
    ensure
      q.finish
    end
  end
  
  def eval_expr_and(q)
    begin
      q = q.save
      r = eval_expr_iand(q)
      if r.nil?
        q.throw
      end
      ary = r
      while q.next_token_is('and')
        s = eval_expr_iand(q)
        if s.nil?
          break
        end
        ary = ary.intersection(s)
      end
      ary
    rescue QStateBack
      q.restore
      nil
    ensure
      q.finish
    end
  end
  
  def eval_expr_iand(q)
    begin
      q = q.save
      r = eval_expr_not(q)
      if r.nil?
        q.throw
      end
      ary = r
      while true
        s = eval_expr_not(q)
        if s.nil?
          break
        end
        ary = ary.intersection(s)
      end
      ary
    rescue QStateBack
      q.restore
      nil
    ensure  
      q.finish
    end
  end
  
  def eval_expr_not(q)
    begin
      q = q.save
      if q.next_token_is('not')
        s = eval_expr_not(q)
        if s.nil?
          q.throw
        end
        return @block.call(nil) - s
      end
      s = eval_expr_par(q)
      if s.nil?
        q.throw
      end
      s
    rescue QStateBack
      q.restore
      nil
    ensure
      q.finish
    end
  end
  
  def eval_expr_par(q)
    begin
      q = q.save
      if q.next_token_is('(')
        r = eval_expr_or(q)
        if r.nil?
          q.throw
        end
        unless q.next_token_is(')')
          q.throw
        end
        return r
      end
      eval_str(q)
    rescue QStateBack
      q.restore
      nil
    ensure
      q.finish
    end
  end
  
  def eval_str(q)
    begin
      q = q.save
      if q.is_empty
        q.throw
      end
      if q.next_token_is_keyword
        q.throw
      end
      
      sentence = q.get_next_token
      @block.call sentence
    rescue QStateBack
      q.restore
      nil
    ensure
      q.finish
    end
  end
end
