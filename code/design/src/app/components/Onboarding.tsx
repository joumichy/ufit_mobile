import { Check, Award, ShoppingBag, TrendingUp, Sparkles } from 'lucide-react';
import { useState } from 'react';

const slides = [
  {
    icon: Sparkles,
    title: 'Curated Fashion Marketplace',
    description: 'Discover exclusive outfits from selected creators and independent brands. Every piece is carefully curated for quality and style.',
    color: 'text-primary',
  },
  {
    icon: Award,
    title: 'Selected Creators Only',
    description: 'Only the best fashion curators make it to UFit. Each creator is vetted for their taste, authenticity, and styling expertise.',
    color: 'text-primary',
  },
  {
    icon: ShoppingBag,
    title: 'Independent Brands',
    description: 'Support emerging designers and sustainable fashion. We partner exclusively with independent European ateliers and ethical manufacturers.',
    color: 'text-primary',
  },
  {
    icon: TrendingUp,
    title: 'Gamified Commission System',
    description: 'Creators earn progressive commissions based on performance. From 8% starter rate to 15% premium tier. The more you sell, the more you earn.',
    color: 'text-primary',
  },
];

interface OnboardingProps {
  onComplete: () => void;
}

export function Onboarding({ onComplete }: OnboardingProps) {
  const [currentSlide, setCurrentSlide] = useState(0);

  const handleNext = () => {
    if (currentSlide < slides.length - 1) {
      setCurrentSlide(currentSlide + 1);
    } else {
      onComplete();
    }
  };

  const handleSkip = () => {
    onComplete();
  };

  const slide = slides[currentSlide];
  const Icon = slide.icon;

  return (
    <div className="min-h-screen bg-white flex flex-col">
      <div className="flex-1 flex flex-col items-center justify-center px-6 py-12">
        <div className="w-full max-w-sm space-y-8">
          <div className="flex items-center justify-center">
            <div className="w-24 h-24 rounded-3xl bg-secondary flex items-center justify-center">
              <Icon className={`w-12 h-12 ${slide.color}`} strokeWidth={1.5} />
            </div>
          </div>

          <div className="text-center space-y-4">
            <h1 className="text-3xl tracking-tight">{slide.title}</h1>
            <p className="text-muted-foreground leading-relaxed">
              {slide.description}
            </p>
          </div>

          <div className="flex justify-center gap-2 py-4">
            {slides.map((_, index) => (
              <div
                key={index}
                className={`h-1.5 rounded-full transition-all ${
                  index === currentSlide
                    ? 'w-8 bg-primary'
                    : 'w-1.5 bg-border'
                }`}
              />
            ))}
          </div>
        </div>
      </div>

      <div className="px-6 pb-8 space-y-3">
        <button
          onClick={handleNext}
          className="w-full bg-primary text-primary-foreground rounded-xl py-4"
        >
          {currentSlide === slides.length - 1 ? 'Get Started' : 'Continue'}
        </button>

        {currentSlide < slides.length - 1 && (
          <button
            onClick={handleSkip}
            className="w-full text-muted-foreground py-3"
          >
            Skip
          </button>
        )}
      </div>
    </div>
  );
}
