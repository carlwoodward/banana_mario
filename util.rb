class Rect
  attr_accessor :x1, :y1, :x2, :y2
  
  def initialize(options)
    self.x1, self.y1, self.x2, self.y2 = options[:x1], options[:y1], options[:x2], options[:y2]
  end
  
  def collide?(rect)
    # wr = widest rectangle, tr = thinest rectange
    wr = rect.width < width ? rect : self
    tr = wr == self ? rect : self
    wr.x1 > tr.x1 and wr.y1 > tr.y1 and wr.x2 < tr.x2 and wr.y2 < tr.y2
  end
  
  def width
    x2 - x1
  end
end