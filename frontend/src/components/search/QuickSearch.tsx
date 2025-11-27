'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { Input } from '@/components/ui/input'
import { Search } from 'lucide-react'

export function QuickSearch() {
  const router = useRouter()
  const [query, setQuery] = useState('')

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter' && query.trim()) {
      // Shift+Enter triggers Ask mode, Enter triggers Search
      const mode = e.shiftKey ? 'ask' : 'search'
      router.push(`/search?q=${encodeURIComponent(query)}&mode=${mode}`)
      setQuery('')
    }
  }

  return (
    <div className="relative w-full max-w-sm">
      <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
      <Input
        type="search"
        placeholder="Search... (⇧ for Ask)"
        className="w-full pl-9 bg-background"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        onKeyDown={handleKeyDown}
        aria-label="Global search - press Enter to search, Shift+Enter to ask"
      />
    </div>
  )
}
