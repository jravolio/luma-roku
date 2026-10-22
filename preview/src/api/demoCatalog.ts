import { TICKS_PER_SECOND, type Item } from './types'

const art = (name: string) => `/demo/art/${name}.jpg`
const minutes = (m: number, s: number) => (m * 60 + s) * TICKS_PER_SECOND

export const DEMO_SAMPLE = {
  url: '/demo/media/caminandes-llama-drama-480p.webm',
  seconds: 89,
  title: 'Caminandes: Llama Drama',
  credit: 'Pablo Vazquez / Blender Foundation · CC BY 3.0',
}

export const demoItems: Item[] = [
  {
    id: 'demo-sintel',
    name: 'Sintel',
    type: 'Movie',
    year: 2010,
    runtimeTicks: minutes(14, 48),
    genres: ['Fantasia', 'Animação', 'Aventura'],
    overview:
      'Uma jovem solitária percorre o mundo em busca do filhote de dragão que resgatou e perdeu. Terceiro filme aberto da Blender Foundation, dirigido por Colin Levy.',
    poster: art('sintel-poster'),
    backdrop: art('sintel-backdrop'),
  },
  {
    id: 'demo-tears-of-steel',
    name: 'Tears of Steel',
    type: 'Movie',
    year: 2012,
    runtimeTicks: minutes(12, 14),
    genres: ['Ficção científica', 'Ação ao vivo'],
    overview:
      'Em uma Amsterdã futurista, cientistas tentam salvar o mundo de robôs destrutivos e reconstruir uma relação rompida. Projeto Mango, dirigido por Ian Hubert.',
    poster: art('tos-poster'),
    backdrop: art('tos-backdrop'),
  },
  {
    id: 'demo-spring',
    name: 'Spring',
    type: 'Movie',
    year: 2019,
    runtimeTicks: minutes(7, 44),
    genres: ['Fantasia', 'Animação'],
    overview:
      'Uma jovem pastora e seu cão enfrentam espíritos antigos para manter o ciclo da vida. Escrito e dirigido por Andy Goralczyk.',
    poster: art('spring-poster'),
    backdrop: art('spring-backdrop'),
  },
  {
    id: 'demo-cosmos-laundromat',
    name: 'Cosmos Laundromat',
    type: 'Movie',
    year: 2015,
    runtimeTicks: minutes(12, 10),
    genres: ['Comédia', 'Drama', 'Animação'],
    overview:
      'Em uma ilha desolada, o carneiro Franck encontra um vendedor misterioso que lhe oferece um presente inesquecível. Dirigido por Mathieu Auvray.',
    poster: art('cosmos-poster'),
    backdrop: art('cosmos-backdrop'),
  },
  {
    id: 'demo-sprite-fright',
    name: 'Sprite Fright',
    type: 'Movie',
    year: 2021,
    runtimeTicks: minutes(10, 29),
    genres: ['Terror', 'Comédia', 'Animação'],
    overview:
      'Adolescentes barulhentos perturbam pequenas criaturas parecidas com cogumelos durante um passeio pela floresta. Dirigido por Matthew Luhn.',
    poster: art('sprite-poster'),
    backdrop: art('sprite-backdrop'),
  },
  {
    id: 'demo-big-buck-bunny',
    name: 'Big Buck Bunny',
    type: 'Movie',
    year: 2008,
    runtimeTicks: minutes(10, 34),
    genres: ['Comédia', 'Família', 'Animação'],
    overview:
      'Um coelho gigante e gentil se vinga de forma elaborada e divertida de três roedores que atormentam a floresta. Projeto Peach, dirigido por Sacha Goedegebure.',
    poster: art('bbb-poster'),
    backdrop: art('bbb-backdrop'),
  },
  {
    id: 'demo-charge',
    name: 'Charge',
    type: 'Movie',
    year: 2022,
    runtimeTicks: minutes(4, 22),
    genres: ['Ação', 'Ficção científica', 'Animação'],
    overview: 'Em um futuro com escassez de energia, um idoso arrisca tudo ao invadir uma instalação elétrica fortemente vigiada.',
    poster: art('charge-poster'),
    backdrop: art('charge-backdrop'),
  },
  {
    id: 'demo-coffee-run',
    name: 'Coffee Run',
    type: 'Movie',
    year: 2020,
    runtimeTicks: minutes(3, 4),
    genres: ['Drama', 'Animação'],
    overview: 'Movida a cafeína, uma jovem percorre as lembranças doces e amargas de sua vida.',
    poster: art('coffee-poster'),
    backdrop: art('coffee-backdrop'),
  },
  {
    id: 'demo-elephants-dream',
    name: 'Elephants Dream',
    type: 'Movie',
    year: 2006,
    runtimeTicks: minutes(10, 58),
    genres: ['Ficção científica', 'Animação'],
    overview:
      'Emo e Proog percorrem os corredores de uma máquina infinita e imprevisível. O primeiro filme aberto da Blender Foundation, dirigido por Bassam Kurdali.',
    poster: art('ed-poster'),
    backdrop: art('ed-backdrop'),
  },
  {
    id: 'demo-caminandes',
    name: 'Caminandes',
    type: 'Series',
    year: 2013,
    genres: ['Comédia', 'Família', 'Animação'],
    overview:
      'A lhama Koro enfrenta os obstáculos da Patagônia com uma ideia teimosa de cada vez. Série de curtas animados criada por Pablo Vazquez.',
    poster: art('caminandes-poster'),
    backdrop: art('caminandes-backdrop'),
  },
  {
    id: 'demo-caminandes-s1',
    name: 'Temporada 1',
    type: 'Season',
    seriesName: 'Caminandes',
    indexNumber: 1,
    poster: art('caminandes-poster'),
    backdrop: art('caminandes-backdrop'),
  },
  {
    id: 'demo-caminandes-e1',
    name: 'Llama Drama',
    type: 'Episode',
    seriesName: 'Caminandes',
    parentIndexNumber: 1,
    indexNumber: 1,
    year: 2013,
    runtimeTicks: minutes(1, 29),
    overview: 'Koro tenta atravessar uma estrada na Patagônia. A estrada não colabora.',
    poster: art('caminandes-e1'),
    backdrop: art('caminandes-e1'),
  },
  {
    id: 'demo-caminandes-e2',
    name: 'Gran Dillama',
    type: 'Episode',
    seriesName: 'Caminandes',
    parentIndexNumber: 1,
    indexNumber: 2,
    year: 2013,
    runtimeTicks: minutes(2, 26),
    overview: 'A grama parece mais verde do outro lado de uma cerca elétrica, e Koro está decidido a chegar lá.',
    poster: art('caminandes-e2'),
    backdrop: art('caminandes-e2'),
  },
  {
    id: 'demo-caminandes-e3',
    name: 'Llamigos',
    type: 'Episode',
    seriesName: 'Caminandes',
    parentIndexNumber: 1,
    indexNumber: 3,
    year: 2016,
    runtimeTicks: minutes(2, 30),
    overview: 'No auge do inverno, Koro conhece Oti, um pinguim insistente que quer as mesmas frutas que ele.',
    poster: art('caminandes-e3'),
    backdrop: art('caminandes-e3'),
  },
]

export const demoParents: Record<string, string> = {
  'demo-caminandes-s1': 'demo-caminandes',
  'demo-caminandes-e1': 'demo-caminandes-s1',
  'demo-caminandes-e2': 'demo-caminandes-s1',
  'demo-caminandes-e3': 'demo-caminandes-s1',
}

export const demoSeedProgress: Record<string, number> = {
  'demo-tears-of-steel': 0.38,
  'demo-caminandes-e2': 0.45,
}

export interface Credit {
  work: string
  file: string
  author: string
  license: string
  licenseUrl: string
  source: string
}

const BY3 = 'https://creativecommons.org/licenses/by/3.0/'
const BY4 = 'https://creativecommons.org/licenses/by/4.0/'
const BY25 = 'https://creativecommons.org/licenses/by/2.5/'
const CC0 = 'https://creativecommons.org/publicdomain/zero/1.0/'
const commons = (file: string) => `https://commons.wikimedia.org/wiki/File:${file}`

export const demoCredits: Credit[] = [
  { work: 'Sintel', file: 'Pôster', author: 'Blender Foundation (durian.blender.org)', license: 'CC BY 3.0', licenseUrl: BY3, source: commons('Sintel_poster.jpg') },
  { work: 'Sintel', file: 'Imagem de fundo', author: 'David Revoy / Blender Foundation', license: 'CC BY 3.0', licenseUrl: BY3, source: commons('Durian_-_Sintel-wallpaper-sintel.jpg') },
  { work: 'Tears of Steel', file: 'Pôster', author: 'Blender Foundation (Project Mango)', license: 'CC BY 3.0', licenseUrl: BY3, source: commons('Tos-poster.png') },
  { work: 'Tears of Steel', file: 'Imagem de fundo', author: 'Blender Foundation (Project Mango)', license: 'CC BY 3.0', licenseUrl: BY3, source: commons('Tears_of_Steel_frame_01_2a.jpg') },
  { work: 'Spring', file: 'Pôster', author: 'Blender Foundation', license: 'CC BY 4.0', licenseUrl: BY4, source: commons('Spring2019AlphaPosterBlender.jpg') },
  { work: 'Spring', file: 'Imagem de fundo', author: 'Alexandru Rosu (cena de Spring, da Blender Foundation)', license: 'CC0', licenseUrl: CC0, source: commons('Blender_Open_Movie_-_Spring_(2019).png') },
  { work: 'Cosmos Laundromat', file: 'Pôster', author: 'Andy Goralczyk e Blender Foundation', license: 'CC BY 4.0', licenseUrl: BY4, source: commons('CosmosLaundromatPoster.jpg') },
  { work: 'Cosmos Laundromat', file: 'Imagem de fundo', author: 'Blender Foundation', license: 'CC BY 4.0', licenseUrl: BY4, source: commons('Franck_the_caterpillar.jpg') },
  { work: 'Sprite Fright', file: 'Pôster', author: 'Blender Studio', license: 'CC BY 4.0', licenseUrl: BY4, source: commons('Sprite_Fright-movie_poster.jpg') },
  { work: 'Sprite Fright', file: 'Imagem de fundo', author: 'Vivien Lulkowski / Blender Foundation', license: 'CC BY 4.0', licenseUrl: BY4, source: commons('Sprite_Fright-concept_art-group.png') },
  { work: 'Big Buck Bunny', file: 'Pôster', author: 'Blender Foundation (peach.blender.org)', license: 'CC BY 3.0', licenseUrl: BY3, source: commons('Big_buck_bunny_poster_big.jpg') },
  { work: 'Big Buck Bunny', file: 'Imagem de fundo', author: 'Blender Foundation (bigbuckbunny.org)', license: 'CC BY 3.0', licenseUrl: BY3, source: commons('Big.Buck.Bunny.-.Frank.Rinky.Gimera.png') },
  { work: 'Charge', file: 'Pôster', author: 'Blender Studio', license: 'CC BY 4.0', licenseUrl: BY4, source: commons('Charge-movie_poster.jpg') },
  { work: 'Charge', file: 'Imagem de fundo', author: 'Blender Studio', license: 'CC BY 4.0', licenseUrl: BY4, source: commons('Charge_-_Blender_Open_Movie-YouTube_thumbnail.jpg') },
  { work: 'Coffee Run', file: 'Pôster (recorte de cena)', author: 'Blender Foundation', license: 'CC BY 4.0', licenseUrl: BY4, source: commons('Coffee_Run_-_screenshot-Location_06_Wedding-Run_1.png') },
  { work: 'Coffee Run', file: 'Imagem de fundo', author: 'Blender Foundation', license: 'CC BY 4.0', licenseUrl: BY4, source: commons('Coffee_Run_-_screenshot-intro.png') },
  { work: 'Elephants Dream', file: 'Pôster (recorte de cena)', author: 'Ton Roosendaal e colaboradores / Blender Foundation', license: 'CC BY 2.5', licenseUrl: BY25, source: commons('Elephants_Dream_s5_both_cropped.jpg') },
  { work: 'Elephants Dream', file: 'Imagem de fundo', author: 'Ton Roosendaal e colaboradores / Blender Foundation', license: 'CC BY 2.5', licenseUrl: BY25, source: commons('Elephants_Dream_s8_proog.jpg') },
  { work: 'Caminandes', file: 'Pôster (recorte de cena) e imagem de fundo', author: 'Blender Foundation', license: 'CC BY 4.0', licenseUrl: BY4, source: commons('Blender_Foundation_-_Caminandes_-_Episode_3_-_Llamigos_-_Koro_and_Oti_share_more_food_to_eat_at_night.png') },
  { work: 'Caminandes: Llama Drama', file: 'Imagem do episódio', author: 'Pablo Vazquez, Beorn Leonard, Francesco Siddi', license: 'CC BY 3.0', licenseUrl: BY3, source: commons('Pablo_Vazquez_-_Caminandes_-_Episode_1_-_Llama_Drama_-_Cover_thumbnail.png') },
  { work: 'Caminandes: Gran Dillama', file: 'Imagem do episódio', author: 'Blender Foundation', license: 'CC BY 3.0', licenseUrl: BY3, source: commons('Blender_Foundation_-_Caminandes_-_Episode_2_-_Gran_Dillama_-_Cover_thumbnail.png') },
  { work: 'Caminandes: Llamigos', file: 'Imagem do episódio', author: 'Blender Foundation', license: 'CC BY 4.0', licenseUrl: BY4, source: commons('Blender_Foundation_-_Caminandes_-_Episode_3_-_Llamigos_-_Cover_thumbnail.png') },
  { work: 'Caminandes: Llama Drama', file: 'Vídeo de exemplo (transcodificado em 480p)', author: 'Pablo Vazquez / Blender Foundation', license: 'CC BY 3.0', licenseUrl: BY3, source: commons('Caminandes-_Llama_Drama_-_Short_Movie.ogv') },
]
