import { Github } from "@medusajs/icons"
import { Button, Heading } from "@medusajs/ui"

const Hero = () => {
  return (
    <div className="h-[75vh] w-full border-b border-ui-border-base relative bg-ui-bg-subtle poop-animated">
      <div className="absolute inset-0 z-10 flex flex-col justify-center items-center text-center small:p-32 gap-6">
        <span>
          <Heading
            level="h1"
            className="text-3xl leading-10 text-ui-fg-base font-normal"
          >
            WrocławskieSzamba24.pl
          </Heading>
          <Heading
            level="h1"
            className="text-2xl leading-10 text-ui-fg-base font-normal"
          >
            (Bez piany, bez przecieków)
          </Heading>
          <Heading
            level="h2"
            className="text-xl leading-10 text-ui-fg-subtle font-normal"
          >
            Powered by Medusa, Next.js & Ażul
          </Heading>
        </span>
        <audio src="/wrcszmb.mp3" loop controls playsInline />
        <a href="https://github.com/wojtazk/wroclawskie-szamba" target="_blank">
          <Button variant="secondary">
            Obczaj na GitHub'ie
            <Github />
          </Button>
        </a>
      </div>
    </div>
  )
}

export default Hero
