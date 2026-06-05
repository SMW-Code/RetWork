import fs from 'fs';
import path from 'path';
import matter from 'gray-matter';
import { remark } from 'remark';
import remarkHtml from 'remark-html';
import remarkGfm from 'remark-gfm';

const POSTS_DIR = path.join(process.cwd(), 'posts');

export type PostMeta = {
  slug: string;
  title: string;
  date: string;
  description?: string;
  image?: string;
  tags?: string[];
  author?: string;
};

export type Post = PostMeta & { contentHtml: string };

/* slug ↔ file name */
function fileToSlug(name: string) {
  return name.replace(/\.md$/, '');
}

export function getAllSlugs(): string[] {
  if (!fs.existsSync(POSTS_DIR)) return [];
  return fs.readdirSync(POSTS_DIR).filter((f) => f.endsWith('.md')).map(fileToSlug);
}

export function getAllPosts(): PostMeta[] {
  const slugs = getAllSlugs();
  const posts = slugs.map((slug) => {
    const file = fs.readFileSync(path.join(POSTS_DIR, `${slug}.md`), 'utf8');
    const { data } = matter(file);
    return {
      slug,
      title: data.title || slug,
      date: data.date || '',
      description: data.description || '',
      image: data.image || '',
      tags: data.tags || [],
      author: data.author || 'RetWork編集部',
    } as PostMeta;
  });
  posts.sort((a, b) => (a.date < b.date ? 1 : -1));
  return posts;
}

export async function getPostBySlug(slug: string): Promise<Post | null> {
  const filePath = path.join(POSTS_DIR, `${slug}.md`);
  if (!fs.existsSync(filePath)) return null;
  const file = fs.readFileSync(filePath, 'utf8');
  const { data, content } = matter(file);
  const processed = await remark().use(remarkGfm).use(remarkHtml, { sanitize: false }).process(content);
  return {
    slug,
    title: data.title || slug,
    date: data.date || '',
    description: data.description || '',
    image: data.image || '',
    tags: data.tags || [],
    author: data.author || 'RetWork編集部',
    contentHtml: processed.toString(),
  };
}
