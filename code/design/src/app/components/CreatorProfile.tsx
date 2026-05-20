import { ArrowLeft, Award, Users, Package } from 'lucide-react';
import { useState, useEffect, useRef } from 'react';

const creatorOutfits = [
  'https://images.unsplash.com/photo-1768825197238-629b1ae2dc18?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=400',
  'https://images.unsplash.com/photo-1763499389975-f27898185f17?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=400',
  'https://images.unsplash.com/photo-1761555687814-15a0cea591ff?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=400',
  'https://images.unsplash.com/photo-1746458258548-5e5bd7225c9c?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=400',
  'https://images.unsplash.com/photo-1774359535371-c9ea5ad2e8ec?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=400',
  'https://images.unsplash.com/photo-1769614552343-a86788218525?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=400',
  'https://images.unsplash.com/photo-1745240261519-0b988d54d098?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=400',
  'https://images.unsplash.com/photo-1765916093860-28dc1bdd2de9?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=400',
];

interface CreatorProfileProps {
  onBack: () => void;
}

export function CreatorProfile({ onBack }: CreatorProfileProps) {
  const [showHeader, setShowHeader] = useState(true);
  const [lastScrollY, setLastScrollY] = useState(0);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const handleScroll = () => {
      const container = containerRef.current;
      if (!container) return;

      const currentScrollY = container.scrollTop;

      if (currentScrollY < 50) {
        setShowHeader(true);
      } else if (currentScrollY > lastScrollY && currentScrollY > 200) {
        setShowHeader(false);
      } else if (currentScrollY < lastScrollY) {
        setShowHeader(true);
      }

      setLastScrollY(currentScrollY);
    };

    const container = containerRef.current;
    if (container) {
      container.addEventListener('scroll', handleScroll);
      return () => container.removeEventListener('scroll', handleScroll);
    }
  }, [lastScrollY]);

  return (
    <div ref={containerRef} className="h-screen overflow-y-auto bg-white pb-20 scrollbar-hide">
      <div className="sticky top-0 z-20 bg-white/95 backdrop-blur-sm border-b border-border">
        <div className="flex items-center px-6 py-4">
          <button onClick={onBack} className="p-2 -ml-2">
            <ArrowLeft className="w-6 h-6" strokeWidth={1.5} />
          </button>
          <h2 className="ml-3">Sofia Laurent</h2>
        </div>
      </div>

      <div
        className={`transition-all duration-500 ease-in-out overflow-hidden ${
          showHeader ? 'max-h-[600px] opacity-100' : 'max-h-0 opacity-0'
        }`}
      >
        <div className="px-6 py-8 space-y-6">
          <div className="flex items-start gap-4">
            <div className="w-20 h-20 rounded-full bg-secondary flex items-center justify-center text-xl">
              SL
            </div>
            <div className="flex-1 space-y-3">
              <div>
                <h1 className="text-xl">Sofia Laurent</h1>
                <p className="text-sm text-muted-foreground">@sofialaurent</p>
              </div>
              <button className="w-full bg-primary text-primary-foreground rounded-xl py-3">
                Follow
              </button>
            </div>
          </div>

          <p className="text-sm text-muted-foreground leading-relaxed">
            Parisian fashion curator. Minimalist aesthetic, timeless pieces. Collaborating with independent European brands to bring you sustainable, high-quality fashion.
          </p>

          <div className="grid grid-cols-3 gap-4">
            <div className="bg-secondary rounded-xl p-4 text-center space-y-1">
              <Users className="w-5 h-5 mx-auto text-muted-foreground" strokeWidth={1.5} />
              <p className="text-xl">12.4k</p>
              <p className="text-xs text-muted-foreground">Followers</p>
            </div>
            <div className="bg-secondary rounded-xl p-4 text-center space-y-1">
              <Package className="w-5 h-5 mx-auto text-muted-foreground" strokeWidth={1.5} />
              <p className="text-xl">87</p>
              <p className="text-xs text-muted-foreground">Outfits</p>
            </div>
            <div className="bg-secondary rounded-xl p-4 text-center space-y-1">
              <Award className="w-5 h-5 mx-auto text-muted-foreground" strokeWidth={1.5} />
              <p className="text-xl">Elite</p>
              <p className="text-xs text-muted-foreground">Grade</p>
            </div>
          </div>

          <div className="bg-secondary rounded-xl p-5 space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-sm text-muted-foreground">Creator Grade</span>
              <div className="flex items-center gap-2">
                <Award className="w-5 h-5 text-primary" strokeWidth={1.5} />
                <span className="text-sm">Elite</span>
              </div>
            </div>
            <div className="w-full bg-white rounded-full h-2 overflow-hidden">
              <div className="bg-primary h-full w-[85%]"></div>
            </div>
            <div className="flex items-center justify-between text-xs">
              <span className="text-muted-foreground">Commission Rate</span>
              <span>12% → 15%</span>
            </div>
            <p className="text-xs text-muted-foreground">
              85 sales to reach Premium tier and unlock 15% commission
            </p>
          </div>
        </div>
      </div>

      <div className={`${!showHeader ? 'pt-0' : 'pt-4'} transition-all duration-500`}>
        <div className="px-6 pb-4">
          <h2 className="text-lg">Published Outfits</h2>
        </div>
        <div className="grid grid-cols-2 gap-0.5 bg-border">
          {creatorOutfits.map((image, index) => (
            <div key={index} className="aspect-[3/4] bg-white overflow-hidden">
              <img
                src={image}
                alt={`Outfit ${index + 1}`}
                className="w-full h-full object-cover"
              />
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
