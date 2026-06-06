import { PropertyGrid } from '@/components/PropertyGrid';

interface Props {
  params: Promise<{ propertyId: string }>;
}

export default async function PropertyGridPage({ params }: Props) {
  const { propertyId } = await params;

  return (
    <div className="space-y-6">
      <PropertyGrid propertyId={propertyId} />
    </div>
  );
}
