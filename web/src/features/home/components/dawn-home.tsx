import { Link } from '@tanstack/react-router'
import { Clipboard, KeyRound, ShieldCheck } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import { useAuthStore } from '@/stores/auth-store'

interface DawnHomeProps {
  className?: string
}

export function DawnHome(props: DawnHomeProps) {
  const { t } = useTranslation()
  const { auth } = useAuthStore()
  const [copied, setCopied] = useState(false)
  const endpoint =
    typeof window === 'undefined' ? '/v1' : `${window.location.origin}/v1`
  const keyLink = auth.user ? (
    <Link to='/keys' />
  ) : (
    <Link to='/sign-in' search={{ redirect: '/keys' }} />
  )

  const handleCopyEndpoint = async () => {
    try {
      await navigator.clipboard.writeText(endpoint)
      setCopied(true)
      toast.success(t('Copied!'))
    } catch {
      toast.error(t('Copy failed'))
    }
  }

  return (
    <section
      aria-labelledby='dawn-home-title'
      className={`relative isolate min-h-[calc(100svh-4rem)] overflow-hidden bg-[#1d2427] text-[#f5f1e9] ${props.className ?? ''}`}
    >
      <div
        aria-hidden='true'
        className='absolute inset-0 -z-20 bg-cover bg-center'
        style={{ backgroundImage: "url('/about/bg-about.webp')" }}
      />
      <div
        aria-hidden='true'
        className='absolute inset-0 -z-10 bg-[linear-gradient(90deg,rgba(15,21,24,0.96)_0%,rgba(15,21,24,0.72)_42%,rgba(15,21,24,0.2)_100%)]'
      />
      <div
        aria-hidden='true'
        className='absolute inset-0 -z-10 bg-[linear-gradient(0deg,rgba(14,19,21,0.76)_0%,transparent_48%)]'
      />

      <div className='mx-auto flex min-h-[calc(100svh-4rem)] w-full max-w-[1440px] flex-col justify-between border-x border-white/10 px-6 pt-24 pb-6 sm:px-10 lg:px-16'>
        <div className='flex items-start justify-between gap-6 text-[10px] font-semibold tracking-[0.22em] text-white/60 uppercase'>
          <span className='landing-animate-fade-up'>AI API gateway</span>
        </div>

        <div className='grid items-end gap-14 py-16 lg:grid-cols-[minmax(0,1fr)_minmax(360px,470px)] lg:gap-24 lg:py-10'>
          <div className='landing-animate-fade-up [animation-delay:140ms]'>
            <h1
              id='dawn-home-title'
              className='w-fit max-w-full font-normal leading-none'
            >
              <span
                className='block leading-[0.9] text-[clamp(4.4rem,13vw,10rem)] tracking-[-0.02em] text-white/85'
                style={{ fontFamily: 'Georgia, "Times New Roman", serif' }}
              >
                Dawn
              </span>
              <span className='mt-2 block text-right text-[clamp(2.5rem,6vw,5.2rem)] leading-none font-medium tracking-[0.01em] text-white/50'>
                router
              </span>
            </h1>
            <div className='mt-8 h-px w-56 bg-gradient-to-r from-[#e6a25c] to-transparent' />
            <p className='mt-5 max-w-sm text-base leading-relaxed text-white/65'>
              {t('Until dawn...')}
            </p>
          </div>

          <div className='landing-animate-fade-left space-y-4 [animation-delay:240ms]'>
            <div className='border border-white/15 bg-[#0c1113]/55 p-5 shadow-2xl backdrop-blur-md sm:p-6'>
              <p className='mb-3 text-[10px] font-semibold tracking-[0.2em] text-white/50 uppercase'>
                {t('Endpoint')}
              </p>
              <div className='flex min-w-0 items-center gap-3 border border-white/15 bg-black/20 px-3 py-3'>
                <code className='min-w-0 flex-1 truncate text-sm text-white/85 sm:text-base'>
                  {endpoint}
                </code>
                <Button
                  type='button'
                  variant='ghost'
                  size='icon'
                  title={t('Copy endpoint')}
                  aria-label={t('Copy endpoint')}
                  className='size-9 shrink-0 text-white/65 hover:bg-white/10 hover:text-[#e6a25c]'
                  onClick={handleCopyEndpoint}
                >
                  <Clipboard className='size-4' />
                </Button>
              </div>
              <p aria-live='polite' className='mt-3 text-xs text-white/40'>
                {copied ? t('Copied!') : t('Copy endpoint')}
              </p>
            </div>

            <Button
              size='lg'
              render={keyLink}
              className='h-12 w-full justify-center rounded-none border border-[#e6a25c] bg-[#e6a25c] px-6 text-sm font-semibold text-[#1d2427] shadow-[0_12px_35px_rgba(230,162,92,0.22)] hover:bg-[#f0b36e]'
            >
              <KeyRound className='size-4' />
              {t('Get API key')}
            </Button>

            <div className='flex items-center gap-3 border-t border-white/15 pt-4 text-xs text-white/65'>
              <ShieldCheck className='size-4 shrink-0 text-[#e6a25c]' />
              <span>{t('Connect only trusted channels')}</span>
            </div>
          </div>
        </div>

        <footer className='border-t border-white/15 pt-4 text-xs text-white/45'>
          {t('Dawn router © 2026')}
        </footer>
      </div>
    </section>
  )
}
